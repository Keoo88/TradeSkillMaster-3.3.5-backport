-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Log = TSM.Auctioning:NewPackage("Log")
local L = TSM.Locale.GetTable()
local Database = TSM.LibTSMUtil:Include("Database")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local private = {
	db = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Log.OnInitialize()
	private.db = Database.NewSchema("AUCTIONING_LOG")
		:AddNumberField("index")
		:AddStringField("itemString")
		:AddStringField("seller")
		:AddNumberField("buyout")
		:AddStringField("operation")
		:AddStringField("reasonStr")
		:AddEnumField("reasonKey", AuctioningOperation.RESULT)
		:AddStringField("state")
		:AddIndex("index")
		:Commit()
end

function Log.Truncate()
	private.db:Truncate()
end

function Log.CreateQuery()
	return private.db:NewQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "")
		:VirtualField("infoStr", "string", Log.GetInfoStr)
		:OrderBy("index", false)
end

function Log.UpdateRowByIndex(index, field, value)
	local row = private.db:NewQuery()
		:Equal("index", index)
		:GetFirstResultAndRelease()

	if field == "state" then
		assert(value == "POSTED" or value == "CANCELLED" or value == "SKIPPED")
		if not row then
			return
		end
	end

	row:SetField(field, value)
		:Update()

	row:Release()
end

function Log.SetQueryUpdatesPaused(paused)
	private.db:SetQueryUpdatesPaused(paused)
end

function Log.AddEntry(itemString, operationName, reasonKey, seller, buyout, index)
	private.db:NewRow()
		:SetField("itemString", itemString)
		:SetField("seller", seller)
		:SetField("buyout", buyout)
		:SetField("operation", operationName)
		:SetField("reasonStr", private.GetResultText(reasonKey))
		:SetField("reasonKey", reasonKey)
		:SetField("index", index)
		:SetField("state", "PENDING")
		:Create()
end

function Log.GetColorFromReasonKey(reasonKey)
	return private.GetResultColor(reasonKey)
end

function Log.GetInfoStr(row)
	local state, reasonKey = row:GetFields("state", "reasonKey")
	if state == "PENDING" then
		return Theme.GetColor(private.GetResultColor(reasonKey)):ColorText(private.GetResultText(reasonKey))
	elseif state == "POSTED" then
		return Theme.GetColor("INDICATOR"):ColorText(L["Posted:"]).." "..private.GetResultText(reasonKey)
	elseif state == "CANCELLED" then
		return Theme.GetColor("INDICATOR"):ColorText(L["Cancelled:"]).." "..private.GetResultText(reasonKey)
	elseif state == "SKIPPED" then
		return Theme.GetColor("INDICATOR"):ColorText(L["Skipped:"]).." "..private.GetResultText(reasonKey)
	else
		error("Invalid state: "..tostring(state))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetResultColor(result)
	if result == AuctioningOperation.RESULT.INVALID then
		return "FEEDBACK_RED"
	elseif result == AuctioningOperation.RESULT.NOT_POSTING then
		return "FEEDBACK_ORANGE"
	elseif result == AuctioningOperation.RESULT.POSTING_NOT_NEEDED then
		return "FEEDBACK_BLUE"
	elseif result == AuctioningOperation.RESULT.POSTING then
		return "FEEDBACK_GREEN"
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING then
		return "FEEDBACK_GREEN"
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED then
		return "FEEDBACK_BLUE"
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS then
		return "FEEDBACK_BLUE"
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL then
		return "FEEDBACK_RED"
	elseif result == AuctioningOperation.RESULT.CANCELING then
		return "FEEDBACK_RED"
	else
		error("Unknown result: "..tostring(result))
	end
end

function private.GetResultText(result)
	if result == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		return L["Item/Group is invalid (see chat)."]
	elseif result == AuctioningOperation.RESULT.INVALID.SELLER then
		return L["Invalid seller data returned by server."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.DISABLED then
		return L["Posting disabled."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.NOT_ENOUGH then
		return L["Not enough items in bags."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.MAX_EXPIRES then
		return L["Above max expires."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.BELOW_MIN then
		return L["Cheapest auction below min price."]
	elseif result == AuctioningOperation.RESULT.POSTING_NOT_NEEDED.TOO_MANY then
		return L["Maximum amount already posted."]
	elseif result == AuctioningOperation.RESULT.POSTING.NORMAL then
		return L["Posting at normal price."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_MIN then
		return L["Below min price. Posting at min."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_MAX then
		return L["Below min price. Posting at max."]
	elseif result == AuctioningOperation.RESULT.POSTING.RESET_NORMAL then
		return L["Below min price. Posting at normal."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_MIN then
		return L["Above max price. Posting at min."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_MAX then
		return L["Above max price. Posting at max."]
	elseif result == AuctioningOperation.RESULT.POSTING.ABOVE_MAX_NORMAL then
		return L["Above max price. Posting at normal."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.ABOVE_MAX_NO_POST then
		return L["Above max price. Not posting."]
	elseif result == AuctioningOperation.RESULT.POSTING.UNDERCUT then
		return L["Undercutting competition."]
	elseif result == AuctioningOperation.RESULT.POSTING.PLAYER then
		return L["Posting at your current price."]
	elseif result == AuctioningOperation.RESULT.POSTING.WHITELIST then
		return L["Posting at whitelisted player's price."]
	elseif result == AuctioningOperation.RESULT.NOT_POSTING.WHITELIST_NO_POST then
		return L["Lowest auction by whitelisted player."]
	elseif result == AuctioningOperation.RESULT.POSTING.BLACKLIST then
		return L["Undercutting blacklisted player."]
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL.DISABLED then
		return L["Canceling disabled."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.NOT_UNDERCUT then
		return L["Your auction has not been undercut."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.BID then
		return L["Auction has been bid on."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.NO_MONEY then
		return L["Not enough money to cancel."]
	elseif result == AuctioningOperation.RESULT.CANCELING_NOT_NEEDED.KEEP_POSTED then
		return L["Keeping undercut auctions posted."]
	elseif result == AuctioningOperation.RESULT.WONT_CANCEL.BELOW_MIN then
		return L["Not canceling auction below min price."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_RESET then
		return L["Not canceling auction at reset price."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_NORMAL then
		return L["At normal price and not undercut."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_ABOVE_MAX then
		return L["At above max price and not undercut."]
	elseif result == AuctioningOperation.RESULT.NOT_CANCELING.AT_WHITELIST then
		return L["Posted at whitelisted player's price."]
	elseif result == AuctioningOperation.RESULT.CANCELING.UNDERCUT then
		return L["You've been undercut."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.REPOST then
		return L["Canceling to repost at higher price."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.RESET then
		return L["Canceling to repost at reset price."]
	elseif result == AuctioningOperation.RESULT.CANCELING.WHITELIST_UNDERCUT then
		return L["Undercut by whitelisted player."]
	elseif result == AuctioningOperation.RESULT.CANCELING_EXCESS.PLAYER_UNDERCUT then
		return L["Canceling auction you've undercut."]
	else
		error("Unknown result: "..tostring(result))
	end
end
