-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local AuctioningOperation = LibTSMSystem:Init("AuctioningOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local Math = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Math")
local String = LibTSMSystem:From("LibTSMUtil"):Include("Lua.String")
local EnumType = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.EnumType")
local Money = LibTSMSystem:From("LibTSMUtil"):Include("UI.Money")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local private = {
	defaultZeroUndercut = nil,
	includeBlacklist = nil,
	includeStackSize = nil,
	maxStackSizeFunc = nil,
	valueLimits = nil,
}
local RESULT = EnumType.NewNested("AUCTIONING_OPERATION_RESULT", {
	INVALID = {
		ITEM_GROUP = {
			ALT_BLACKLISTED = EnumType.NewValue(),
			BLACKLIST_WHITELIST = EnumType.NewValue(),
			POST_CAP = EnumType.NewValue(),
			STACK_SIZE = EnumType.NewValue(),
			KEEP_QUANTITY = EnumType.NewValue(),
			MAX_EXPIRES = EnumType.NewValue(),
			MIN_PRICE = EnumType.NewValue(),
			MAX_PRICE = EnumType.NewValue(),
			NORMAL_PRICE = EnumType.NewValue(),
			UNDERCUT = EnumType.NewValue(),
			NORMAL_BELOW_MIN = EnumType.NewValue(),
			MAX_BELOW_MIN = EnumType.NewValue(),
			CANCEL_REPOST_THRESHOLD = EnumType.NewValue(),
			OTHER = EnumType.NewValue(),
		},
		SELLER = EnumType.NewValue(),
	},
	POSTING = {
		NORMAL = EnumType.NewValue(),
		RESET_MIN = EnumType.NewValue(),
		RESET_MAX = EnumType.NewValue(),
		RESET_NORMAL = EnumType.NewValue(),
		ABOVE_MAX_MIN = EnumType.NewValue(),
		ABOVE_MAX_MAX = EnumType.NewValue(),
		ABOVE_MAX_NORMAL = EnumType.NewValue(),
		UNDERCUT = EnumType.NewValue(),
		PLAYER = EnumType.NewValue(),
		WHITELIST = EnumType.NewValue(),
		BLACKLIST = EnumType.NewValue(),
	},
	NOT_POSTING = {
		DISABLED = EnumType.NewValue(),
		NOT_ENOUGH = EnumType.NewValue(),
		MAX_EXPIRES = EnumType.NewValue(),
		BELOW_MIN = EnumType.NewValue(),
		ABOVE_MAX_NO_POST = EnumType.NewValue(),
		WHITELIST_NO_POST = EnumType.NewValue(),
	},
	POSTING_NOT_NEEDED = {
		TOO_MANY = EnumType.NewValue(),
	},
	CANCELING = {
		UNDERCUT = EnumType.NewValue(),
		WHITELIST_UNDERCUT = EnumType.NewValue(),
	},
	NOT_CANCELING = {
		NOT_UNDERCUT = EnumType.NewValue(),
		AT_RESET = EnumType.NewValue(),
		AT_NORMAL = EnumType.NewValue(),
		AT_ABOVE_MAX = EnumType.NewValue(),
		AT_WHITELIST = EnumType.NewValue(),
	},
	CANCELING_NOT_NEEDED = {
		BID = EnumType.NewValue(),
		NO_MONEY = EnumType.NewValue(),
		KEEP_POSTED = EnumType.NewValue(),
	},
	CANCELING_EXCESS = {
		REPOST = EnumType.NewValue(),
		RESET = EnumType.NewValue(),
		PLAYER_UNDERCUT = EnumType.NewValue(),
	},
	WONT_CANCEL = {
		DISABLED = EnumType.NewValue(),
		BELOW_MIN = EnumType.NewValue(),
	},
})
AuctioningOperation.RESULT = RESULT
local OPERATION_TYPE = "Auctioning"
local COPPER_PER_SILVER = 100
local VALID_PRICE_KEYS = {
	minPrice = true,
	normalPrice = true,
	maxPrice = true,
	undercut = true,
	cancelRepostThreshold = true,
	priceReset = true,
	aboveMax = true,
	postCap = true,
	stackSize = true,
	keepQuantity = true,
	maxExpires = true,
}
local IS_GOLD_PRICE_KEY = {
	minPrice = true,
	normalPrice = true,
	maxPrice = true,
	undercut = nil, -- Set by AuctioningOperation.Load()
	priceReset = true,
	aboveMax = true,
}

---@class AuctioningOperationLowestAuction
---@field hasInvalidSeller boolean
---@field isWhitelist boolean
---@field isBlacklist boolean
---@field isPlayer boolean
---@field buyout number
---@field bid number
---@field seller string
---@field auctionId number

---@class AuctioningOperationListedAuction
---@field auctionId number
---@field itemBuyout number
---@field itemBid number
---@field stackSize number
---@field duration number
---@field hasBid boolean
---@field canAffordCancel boolean

---@class AuctioningOperationCancelScanResult
---@field isPlayerOnlySeller boolean
---@field playerLowestItemBuyout? number
---@field playerLowestAuctionId? number
---@field secondLowestBuyout number
---@field nonPlayerLowestAuctionId? number



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctioningOperation:OnModuleLoad(function()
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = nil
		if key == "aboveMax" or key == "priceReset" then
			-- Redirect to the selected price (if applicable)
			local priceKey = operationSettings[key]
			if VALID_PRICE_KEYS[priceKey] then
				value = Util.GetItemPrice(OPERATION_TYPE, itemString, priceKey, operationSettings)
			end
		else
			value = CustomString.GetValue(operationSettings[key], itemString, not IS_GOLD_PRICE_KEY[key])
		end
		if LibTSMSystem.IsRetail() and IS_GOLD_PRICE_KEY[key] then
			value = value and Math.Ceil(value, COPPER_PER_SILVER) or nil
		end
		local limits = private.valueLimits[key]
		if limits and value and (value < limits.min or value > limits.max) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Auctioning operation code.
---@param localizedName string The localized operation type name
---@param defaultZeroUndercut boolean Whether the default undercut should be 0c
---@param includeBlacklist boolean Whether to include blacklist settings
---@param maxStackSizeFunc? fun(itemString: string): number Function to look up the max stack size (or nil if stack size shouldn't be considered)
function AuctioningOperation.Load(localizedName, defaultZeroUndercut, includeBlacklist, maxStackSizeFunc)
	assert(not private.valueLimits)
	private.defaultZeroUndercut = defaultZeroUndercut
	private.includeBlacklist = includeBlacklist
	private.includeStackSize = maxStackSizeFunc and true or false
	private.maxStackSizeFunc = maxStackSizeFunc
	private.valueLimits = {
		keepQuantity = { min = 0, max = 50000 },
		maxExpires = { min = 0, max = 50000 },
		postCap = { min = 0, max = maxStackSizeFunc and 200 or 50000 },
		stackSize = maxStackSizeFunc and { min = 1, max = 200 } or nil,
	}
	if not defaultZeroUndercut then
		IS_GOLD_PRICE_KEY.undercut = true
	end
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 20)
		:SetCustomSanitizeFunc(private.SanitizeSettings)
		:AddNumberSetting("ignoreLowDuration")
		:AddCustomStringSetting("postCap", "5")
		:AddCustomStringSetting("keepQuantity", "0")
		:AddCustomStringSetting("maxExpires", "0")
		:AddNumberSetting("duration", 2, private.SanitizeDuration)
		:AddNumberSetting("bidPercent", 1)
		:AddCustomStringSetting("undercut", defaultZeroUndercut and "0c" or "1c", private.SanitizeUndercut)
		:AddCustomStringSetting("minPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(0.25*avg(crafting,dbmarket,dbregionmarketavg),1.5*vendorsell))")
		:AddCustomStringSetting("maxPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(5*avg(crafting,dbmarket,dbregionmarketavg),30*vendorsell))")
		:AddCustomStringSetting("normalPrice", "check(first(crafting,dbmarket,dbregionmarketavg),max(2*avg(crafting,dbmarket,dbregionmarketavg),12*vendorsell))")
		:AddStringSetting("priceReset", "none")
		:AddStringSetting("aboveMax", "maxPrice")
		:AddBooleanSetting("cancelUndercut", true)
		:AddBooleanSetting("cancelRepost", true)
		:AddCustomStringSetting("cancelRepostThreshold", "1g")
	if includeBlacklist then
		operationType:AddStringSetting("blacklist")
	end
	if maxStackSizeFunc then
		operationType:AddBooleanSetting("matchStackSize")
		operationType:AddCustomStringSetting("stackSize", "1")
		operationType:AddBooleanSetting("stackSizeIsCap")
	end
	Operation.RegisterType(operationType)
end

---Gets the min and max value for a setting.
---@param key "keepQuantity"|"maxExpires"|"postCap"|"stackSize"
---@return number minVal
---@return number maxVal
function AuctioningOperation.GetMinMaxValues(key)
	local limits = private.valueLimits[key]
	assert(limits)
	return limits.min, limits.max
end

---Adds a player to the blacklist.
---@param operationName string The operation name
---@param player string The name of the player to remove
function AuctioningOperation.RemoveBlacklistPlayer(operationName, player)
	assert(private.includeBlacklist)
	local operation = Operation.GetSettings(OPERATION_TYPE, operationName)
	if operation.blacklist == player then
		operation.blacklist = ""
	else
		-- Handle cases where this entry is at the start, in the middle, and at the end
		operation.blacklist = gsub(operation.blacklist, "^"..player..",", "")
		operation.blacklist = gsub(operation.blacklist, ","..player..",", ",")
		operation.blacklist = gsub(operation.blacklist, ","..player.."$", "")
	end
end

---Gets the value of a price setting for a given item and (optionally) operation.
---@param itemString string The item string
---@param key string The setting key
---@param operationSettings? OperationSettings The operation settings to use (otherwise looks up the first one for the item)
---@return number?
function AuctioningOperation.GetItemPrice(itemString, key, operationSettings)
	return Util.GetItemPrice(OPERATION_TYPE, itemString, key, operationSettings)
end

---Returns whether or not an auction is filtered by the operation
---@param itemString string The item string
---@param operationSettings OperationSettings The operation settings
---@param itemBuyout number The auction item buyout
---@param quantity number The auction stack size
---@param timeLeft number The auction duration
---@return boolean
function AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft)
	if timeLeft <= operationSettings.ignoreLowDuration then
		-- Ignoring low duration
		return true
	elseif private.maxStackSizeFunc and operationSettings.matchStackSize and quantity ~= AuctioningOperation.GetItemPrice(itemString, "stackSize", operationSettings) then
		-- Matching stack size
		return true
	elseif operationSettings.priceReset == "ignore" then
		local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
		local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
		if minPrice and itemBuyout - undercut < minPrice then
			-- Ignoring auctions below threshold
			return true
		end
	end
	return false
end

---Returns whether or not the player is blacklisted by the operation.
---@param operationSettings OperationSettings The operation settings
---@param playerName string The player name
---@return boolean
function AuctioningOperation.IsBlacklisted(operationSettings, playerName)
	return String.SeparatedContains(strlower(operationSettings.blacklist), ",", strlower(playerName))
end

---Returns whether or not more scan data is needed to make a posting decision.
---@param itemString string The item string
---@param operationSettings OperationSettings The operation settings
function AuctioningOperation.ShouldKeepScanningForPosting(itemString, operationSettings, minItemBuyout, maxItemBuyout)
	local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
	local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
	if not minPrice or not undercut then
		-- The min price or undercut is not valid, so just keep scanning
		return true
	elseif minItemBuyout - undercut <= minPrice then
		local resetPrice = AuctioningOperation.GetItemPrice(itemString, "priceReset", operationSettings)
		if operationSettings.priceReset == "ignore" or (resetPrice and maxItemBuyout <= resetPrice) then
			-- We need to keep scanning to handle the reset price (always keep scanning for "ignore")
			return true
		end
	end
end

---Validates an operation for posting.
---@param itemString string The item string
---@param num number The number of items to consider posting
---@param operationName any
---@param operationSettings any
---@return boolean? shouldPost
---@return EnumValue|number? errTypeOrNum
---@return any errArg
---@return any errArg2
function AuctioningOperation.ValidateForPosting(itemString, num, operationName, operationSettings)
	local postCap = AuctioningOperation.GetItemPrice(itemString, "postCap", operationSettings)
	if not postCap then
		return nil, RESULT.INVALID.ITEM_GROUP.POST_CAP, operationSettings.postCap
	elseif postCap == 0 then
		-- Posting disabled
		return nil, RESULT.NOT_POSTING.DISABLED
	end

	local stackSize = nil
	local minPostQuantity = nil
	if private.maxStackSizeFunc then
		stackSize = AuctioningOperation.GetItemPrice(itemString, "stackSize", operationSettings)
		-- Check the stack size
		if not stackSize then
			return nil, RESULT.INVALID.ITEM_GROUP.STACK_SIZE, operationSettings.stackSize
		end
		local maxStackSize = private.maxStackSizeFunc(itemString)
		minPostQuantity = operationSettings.stackSizeIsCap and 1 or stackSize
		if not maxStackSize then
			return false, RESULT.INVALID.ITEM_GROUP.STACK_SIZE
		elseif maxStackSize < minPostQuantity then
			-- Invalid stack size
			return nil
		end
	else
		minPostQuantity = 1
	end

	-- Check that we have enough to post
	local keepQuantity = AuctioningOperation.GetItemPrice(itemString, "keepQuantity", operationSettings)
	if not keepQuantity then
		-- Invalid keepQuantity setting
		return nil, RESULT.INVALID.ITEM_GROUP.KEEP_QUANTITY, operationSettings.keepQuantity
	end
	num = num - keepQuantity
	if num < minPostQuantity then
		-- Not enough items to post for this operation
		return nil, RESULT.NOT_POSTING.NOT_ENOUGH
	end

	-- Check the max expires
	local maxExpires = AuctioningOperation.GetItemPrice(itemString, "maxExpires", operationSettings)
	if not maxExpires then
		-- Invalid maxExpires setting
		return nil, RESULT.INVALID.ITEM_GROUP.MAX_EXPIRES, operationSettings.maxExpires
	end
	if maxExpires > 0 then
		local numExpires = CustomString.GetValue("NumExpires", itemString)
		if numExpires and numExpires > maxExpires then
			-- Too many expires, so ignore this operation
			return nil, RESULT.NOT_POSTING.MAX_EXPIRES
		end
	end

	local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = AuctioningOperation.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = AuctioningOperation.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
	if not minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MIN_PRICE, operationSettings.minPrice
	elseif not maxPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MAX_PRICE, operationSettings.maxPrice
	elseif not normalPrice then
		return false, RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE, operationSettings.normalPrice
	elseif not undercut then
		return false, RESULT.INVALID.ITEM_GROUP.UNDERCUT, operationSettings.undercut
	elseif normalPrice < minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN, operationSettings.normalPrice, operationSettings.minPrice
	elseif maxPrice < minPrice then
		return false, RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN, operationSettings.maxPrice, operationSettings.minPrice
	end

	if private.maxStackSizeFunc then
		if not operationSettings.stackSizeIsCap then
			num = Math.Floor(num, stackSize)
		end
		num = min(stackSize * postCap, num)
	else
		num = min(num, postCap)
	end
	return true, num
end

---Makes a posting decision for an item.
---@param itemString string The item string
---@param lowestAuction AuctioningOperationLowestAuction? The lowest auction info
---@param operationSettings OperationSettings The operation settings to use
---@param matchWhitelist boolean Whether or not to match whitelisted auctions
---@return EnumValue result
---@return string? seller
---@return number? bid
---@return number? buyout
---@return number? acitveAuctionsBid
---@return number? activeAuctionsBuyout
function AuctioningOperation.MakePostDecision(itemString, lowestAuction, operationSettings, matchWhitelist)
	local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = AuctioningOperation.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = AuctioningOperation.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
	local resetPrice = AuctioningOperation.GetItemPrice(itemString, "priceReset", operationSettings)
	local aboveMax = AuctioningOperation.GetItemPrice(itemString, "aboveMax", operationSettings)

	local reason, bid, buyout, seller, activeAuctionsBid, activeAuctionsBuyout = nil, nil, nil, nil, nil, nil
	if not lowestAuction then
		-- Post as many as we can at the normal price
		reason = RESULT.POSTING.NORMAL
		buyout = normalPrice
	elseif lowestAuction.hasInvalidSeller then
		return RESULT.INVALID.SELLER
	elseif lowestAuction.isBlacklist and lowestAuction.isPlayer then
		return RESULT.INVALID.ITEM_GROUP.ALT_BLACKLISTED
	elseif lowestAuction.isBlacklist and lowestAuction.isWhitelist then
		return RESULT.INVALID.ITEM_GROUP.BLACKLIST_WHITELIST
	elseif lowestAuction.buyout - undercut < minPrice then
		seller = lowestAuction.seller
		if resetPrice then
			-- Lowest is below the min price, but there is a reset price
			if operationSettings.priceReset == "minPrice" then
				reason = RESULT.POSTING.RESET_MIN
			elseif operationSettings.priceReset == "maxPrice" then
				reason = RESULT.POSTING.RESET_MAX
			elseif operationSettings.priceReset == "normalPrice" then
				reason = RESULT.POSTING.RESET_NORMAL
			else
				error("Invalid below min price: "..tostring(operationSettings.priceReset))
			end
			buyout = resetPrice
			bid = max(bid or buyout * operationSettings.bidPercent, minPrice)
			activeAuctionsBid = floor(bid)
			activeAuctionsBuyout = buyout
		elseif lowestAuction.isBlacklist then
			-- Undercut the blacklisted player
			reason = RESULT.POSTING.BLACKLIST
			buyout = lowestAuction.buyout - undercut
		else
			-- Don't post this item
			return RESULT.NOT_POSTING.BELOW_MIN, seller
		end
	elseif lowestAuction.isPlayer or (lowestAuction.isWhitelist and matchWhitelist) then
		-- We (or a whitelisted play we should match) are lowest, so match the current price and post as many as we can
		activeAuctionsBid = lowestAuction.bid
		activeAuctionsBuyout = lowestAuction.buyout
		if lowestAuction.isPlayer then
			reason = RESULT.POSTING.PLAYER
		else
			reason = RESULT.POSTING.WHITELIST
		end
		bid = lowestAuction.bid
		buyout = lowestAuction.buyout
		seller = lowestAuction.seller
	elseif lowestAuction.isWhitelist then
		-- Don't undercut a whitelisted player
		seller = lowestAuction.seller
		return RESULT.NOT_POSTING.WHITELIST_NO_POST, seller
	elseif (lowestAuction.buyout - undercut) > maxPrice then
		-- We'd be posting above the max price, so resort to the aboveMax setting
		seller = lowestAuction.seller
		if operationSettings.aboveMax == "minPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_MIN
		elseif operationSettings.aboveMax == "maxPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_MAX
		elseif operationSettings.aboveMax == "normalPrice" then
			reason = RESULT.POSTING.ABOVE_MAX_NORMAL
		elseif operationSettings.aboveMax == "none" then
			return RESULT.NOT_POSTING.ABOVE_MAX_NO_POST
		else
			error("Invalid above max price: "..tostring(operationSettings.aboveMax))
		end
		buyout = aboveMax
	else
		-- We just need to do a normal undercut of the lowest auction
		reason = RESULT.POSTING.UNDERCUT
		buyout = lowestAuction.buyout - undercut
		seller = lowestAuction.seller
	end
	if reason == RESULT.POSTING.BLACKLIST then
		bid = bid or buyout * operationSettings.bidPercent
	else
		buyout = max(buyout, minPrice)
		bid = max(bid or buyout * operationSettings.bidPercent, minPrice)
	end
	assert(reason == RESULT.POSTING)
	return reason, seller, bid, buyout, activeAuctionsBid, activeAuctionsBuyout
end

---Gets additional posting settings.
---@param operationSettings OperationSettings The operation settings
---@return number duration
---@return boolean stackSizeIsCap
function AuctioningOperation.GetPostSettings(operationSettings)
	return operationSettings.duration, private.maxStackSizeFunc and operationSettings.stackSizeIsCap or false
end

---Gets the number of items to consider posting.
---@param itemString string The item string
---@param operationSettings OperationSettings The operation settings
---@param numHave number The number available to post
---@param maxStackSize? number The max stack size (only required if configured with maxStackSizeFunc)
---@return number maxCanPost
---@return number perAuction
function AuctioningOperation.GetPostQuantities(itemString, operationSettings, numHave)
	local perAuction, maxCanPost = nil, nil
	local postCap = AuctioningOperation.GetItemPrice(itemString, "postCap", operationSettings)
	if private.maxStackSizeFunc then
		local stackSize = AuctioningOperation.GetItemPrice(itemString, "stackSize", operationSettings)
		local maxStackSize = private.maxStackSizeFunc(itemString)
		if stackSize > maxStackSize and not operationSettings.stackSizeIsCap then
			return nil, nil
		end

		perAuction = min(stackSize, maxStackSize)
		maxCanPost = min(floor(numHave / perAuction), postCap)
		if maxCanPost == 0 then
			if operationSettings.stackSizeIsCap then
				perAuction = numHave
				maxCanPost = 1
			else
				-- Not enough for single post
				return nil, nil
			end
		end
	else
		perAuction = min(postCap, numHave)
		maxCanPost = 1
	end
	return maxCanPost, perAuction, postCap
end

---Validates an operation for canceling.
---@param itemString string The item string
---@param operationSettings OperationSettings The operation settings
---@return EnumValue? errType
---@return any errArg
---@return any errArg2
function AuctioningOperation.ValidateForCanceling(itemString, operationSettings)
	if not operationSettings.cancelUndercut and not operationSettings.cancelRepost then
		return RESULT.WONT_CANCEL.DISABLED
	end

	local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
	local normalPrice = AuctioningOperation.GetItemPrice(itemString, "normalPrice", operationSettings)
	local maxPrice = AuctioningOperation.GetItemPrice(itemString, "maxPrice", operationSettings)
	local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
	local cancelRepostThreshold = AuctioningOperation.GetItemPrice(itemString, "cancelRepostThreshold", operationSettings)
	if not minPrice then
		return RESULT.INVALID.ITEM_GROUP.MIN_PRICE, operationSettings.minPrice
	elseif not maxPrice then
		return RESULT.INVALID.ITEM_GROUP.MAX_PRICE, operationSettings.maxPrice
	elseif not normalPrice then
		return RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE, operationSettings.normalPrice
	elseif operationSettings.cancelRepost and not cancelRepostThreshold then
		return RESULT.INVALID.ITEM_GROUP.CANCEL_REPOST_THRESHOLD, operationSettings.cancelRepostThreshold
	elseif not undercut then
		return RESULT.INVALID.ITEM_GROUP.UNDERCUT, operationSettings.undercut
	elseif maxPrice < minPrice then
		return RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN, operationSettings.maxPrice, operationSettings.minPrice
	elseif normalPrice < minPrice then
		return RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN, operationSettings.normalPrice, operationSettings.minPrice
	else
		return nil
	end
end

---Makes a canceling decision for an item.
---@param itemString string The item string
---@param operationSettings OperationSettings The operation settings to use
---@param lowestAuction AuctioningOperationLowestAuction? The lowest auction info
---@param listedAuction AuctioningOperationListedAuction The listed auction info
---@param scanResult AuctioningOperationCancelScanResult The scan result info
---@return boolean handled
---@return EnumValue? result
function AuctioningOperation.MakeCancelDecision(itemString, operationSettings, lowestAuction, listedAuction, scanResult)
	if private.maxStackSizeFunc and operationSettings.matchStackSize and listedAuction.stackSize ~= AuctioningOperation.GetItemPrice(itemString, "stackSize", operationSettings) then
		return false
	elseif listedAuction.hasBid then
		-- Don't cancel an auction if it has a bid and we're set to not cancel those
		return true, AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.BID
	elseif not listedAuction.canAffordCancel then
		return true, AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.NO_MONEY
	end


	local normalPrice = AuctioningOperation.GetItemPrice(itemString, "normalPrice", operationSettings)
	local cancelRepostThreshold = AuctioningOperation.GetItemPrice(itemString, "cancelRepostThreshold", operationSettings)
	if not lowestAuction then
		-- All auctions which are posted (including ours) have been ignored, so check if we should cancel to repost higher
		if operationSettings.cancelRepost and normalPrice - listedAuction.itemBuyout > cancelRepostThreshold then
			return true, AuctioningOperation.RESULT.CANCELING_EXCESS.REPOST
		else
			return false, AuctioningOperation.RESULT.NOT_CANCELING.NOT_UNDERCUT
		end
	elseif lowestAuction.hasInvalidSeller then
		return false, AuctioningOperation.RESULT.INVALID.SELLER
	end

	local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
	local maxPrice = AuctioningOperation.GetItemPrice(itemString, "maxPrice", operationSettings)
	local resetPrice = AuctioningOperation.GetItemPrice(itemString, "priceReset", operationSettings)
	local undercut = AuctioningOperation.GetItemPrice(itemString, "undercut", operationSettings)
	local aboveMax = AuctioningOperation.GetItemPrice(itemString, "aboveMax", operationSettings)
	if listedAuction.itemBuyout < minPrice and not lowestAuction.isBlacklist then
		-- This auction is below the min price
		if operationSettings.cancelRepost and resetPrice and listedAuction.itemBuyout < (resetPrice - cancelRepostThreshold) then
			-- Canceling to post at reset price
			return true, RESULT.CANCELING_EXCESS.RESET
		else
			return false, RESULT.WONT_CANCEL.BELOW_MIN
		end
	elseif lowestAuction.buyout < minPrice and not lowestAuction.isBlacklist then
		-- Lowest buyout is below min price, so do nothing
		return false, RESULT.WONT_CANCEL.BELOW_MIN
	elseif operationSettings.cancelUndercut and scanResult.playerLowestItemBuyout and ((listedAuction.itemBuyout - undercut) > scanResult.playerLowestItemBuyout or (private.defaultZeroUndercut and (listedAuction.itemBuyout - undercut) == scanResult.playerLowestItemBuyout and listedAuction.auctionId ~= scanResult.playerLowestAuctionId and listedAuction.auctionId < (scanResult.nonPlayerLowestAuctionId or 0))) then
		-- We've undercut this auction
		return true, RESULT.CANCELING_EXCESS.PLAYER_UNDERCUT
	elseif scanResult.isPlayerOnlySeller then
		-- We are the only auction
		if operationSettings.cancelRepost and (normalPrice - listedAuction.itemBuyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.AT_NORMAL
		end
	elseif lowestAuction.isPlayer and scanResult.secondLowestBuyout and scanResult.secondLowestBuyout > maxPrice then
		-- We are posted at the aboveMax price with no competition under our max price
		if operationSettings.cancelRepost and operationSettings.aboveMax ~= "none" and (aboveMax - listedAuction.itemBuyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.AT_ABOVE_MAX
		end
	elseif lowestAuction.isPlayer then
		-- We are the loewst auction
		if operationSettings.cancelRepost and scanResult.secondLowestBuyout and ((scanResult.secondLowestBuyout - undercut) - lowestAuction.buyout) > cancelRepostThreshold then
			-- We can repost higher
			return true, RESULT.CANCELING_EXCESS.REPOST
		else
			return false, RESULT.NOT_CANCELING.NOT_UNDERCUT
		end
	elseif not operationSettings.cancelUndercut then
		-- We're undercut but not canceling undercut auctions
		return false, nil
	elseif lowestAuction.isWhitelist and listedAuction.itemBuyout == lowestAuction.buyout then
		-- At whitelisted player price
		return true, RESULT.NOT_CANCELING.AT_WHITELIST
	elseif not lowestAuction.isWhitelist then
		-- We've been undercut by somebody not on our whitelist
		return true, RESULT.CANCELING.UNDERCUT
	elseif listedAuction.itemBuyout ~= lowestAuction.buyout or listedAuction.itemBid ~= lowestAuction.bid then
		-- Somebody on our whitelist undercut us (or their bid is lower)
		return true, RESULT.CANCELING.WHITELIST_UNDERCUT
	else
		error("Should not get here")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizeSettings(operation)
	if not private.includeStackSize and operation.stackSize and tonumber(operation.postCap) and tonumber(operation.stackSize) then
		operation.postCap = tonumber(operation.postCap) * tonumber(operation.stackSize)
	end
	if private.defaultZeroUndercut and (type(operation.undercut) == "number" and operation.undercut or Money.FromString(operation.undercut) or math.huge) < COPPER_PER_SILVER then
		operation.undercut = "0c"
	end
end

function private.SanitizeDuration(value)
	-- convert from 12/24/48 durations to 1/2/3 API values
	if value == 12 then
		return 1
	elseif value == 24 then
		return 2
	elseif value == 48 then
		return 3
	else
		return value
	end
end

function private.SanitizeUndercut(value)
	if private.defaultZeroUndercut and (Money.FromString(Money.ToStringExact(value) or value) or math.huge) < COPPER_PER_SILVER then
		return "0c"
	end
	return value
end
