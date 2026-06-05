-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionSearchContext = LibTSMService:DefineClassType("AuctionSearchContext")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

---Creates a new shopping search context object.
---@param threadId string The thread ID for running the scan
---@param marketValueFunc fun(subRow: AuctionSubRow): number? The function for looking up the market value of an item
---@param gatheringResultsFunction function The gathering results function
---@return AuctionSearchContext
function AuctionSearchContext:__init(threadId, marketValueFunc, gatheringResultsFunction)
	assert(threadId and marketValueFunc)
	self._threadId = threadId
	self._marketValueFunc = marketValueFunc
	self._gatheringResultsFunction = gatheringResultsFunction
	self._name = nil
	self._filterInfo = nil
	self._postContext = nil
	self._buyCallback = nil
	self._stateCallback = nil
	self._pctTooltip = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the scan context.
---@param name string The name of the scan
---@param filterInfo any
---@param postContext AuctionPostContext The post context
---@param pctTooltip string The percent tooltip
---@return AuctionSearchContext
function AuctionSearchContext:SetScanContext(name, filterInfo, postContext, pctTooltip)
	assert(name)
	self._name = name
	self._filterInfo = filterInfo
	self._postContext = postContext
	-- Clear the callbacks when the scan context changes
	self._buyCallback = nil
	self._stateCallback = nil
	self._pctTooltip = pctTooltip
	return self
end

---Sets callbacks.
---@param buyCallback fun(itemString: string, quantity: number) Callback for items purchased
---@param stateCallback fun(state: string) Callback for state updates
---@return AuctionSearchContext
function AuctionSearchContext:SetCallbacks(buyCallback, stateCallback)
	self._buyCallback = buyCallback
	self._stateCallback = stateCallback
	return self
end

---Starts the scan thread.
---@param callback function The callback for when the thread finishes
---@param auctionScan AuctionScanManager The auction scan object to store the results in
function AuctionSearchContext:StartThread(callback, auctionScan)
	Threading.SetCallback(self._threadId, callback)
	Threading.Start(self._threadId, auctionScan, self._filterInfo, self._postContext)
end

---Kills the scan thread.
function AuctionSearchContext:KillThread()
	Threading.Kill(self._threadId)
end

---Gets the market value function.
---@return function
function AuctionSearchContext:GetMarketValueFunc()
	return self._marketValueFunc
end

---Gets the gathering results function.
---@return function
function AuctionSearchContext:GetGatheringResultsFunc()
	return self._gatheringResultsFunction
end

---Gets the percent tooltip.
---@return string
function AuctionSearchContext:GetPctTooltip()
	return self._pctTooltip
end

---Gets the max quantity of an item that can be bought.
---@param itemString string The item string
---@return number?
function AuctionSearchContext:GetMaxCanBuy(itemString)
	return nil
end

---Handles an item being bought.
---@param itemString string The item string
---@param quantity number The number bought
function AuctionSearchContext:OnBuy(itemString, quantity)
	if self._buyCallback then
		self._buyCallback(itemString, quantity)
	end
end

---Handles state changes.
---@param state string The search state
function AuctionSearchContext:OnStateChanged(state)
	if self._stateCallback then
		self._stateCallback(state)
	end
end

---Gets the name of the search.
---@return string
function AuctionSearchContext:GetName()
	return self._name
end

---Returns the post context.
---@return AuctionPostContext
function AuctionSearchContext:GetPostContext()
	return self._postContext
end
