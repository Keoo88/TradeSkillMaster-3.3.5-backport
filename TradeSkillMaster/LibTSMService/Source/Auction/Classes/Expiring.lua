-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Expiring = LibTSMService:Init("Auction.Expiring")
local Scanner = LibTSMService:Include("Auction.Scanner")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	storage = nil,
	callbacks = {},
}
local DURATION_ENUM_VALUES = {
	[1] = 0.5 * 60 * 60,
	[2] = 2 * 60 * 60,
	[3] = 12 * 60 * 60,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param expiresData table<string,number> Auction expires
function Expiring.Load(expiresData)
	private.storage = expiresData
end

---Starts auction expiring tracking.
function Expiring.Start()
	Scanner.RegisterThrottledIndexCallback(private.HandleThrottledAuctionsUpdate)
	AuctionHouse.SecureHookPost(private.PostAuctionHookHandler)
end

---Registers a callback for when the expires data changes.
---@param callback fun() The callback function
function Expiring.RegisterCallback(callback)
	tinsert(private.callbacks, callback)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleThrottledAuctionsUpdate()
	local nextExpire = nil
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		nextExpire = Scanner.NewIndexQuery()
			:MinAndRelease("duration")
	else
		local minDuration = Scanner.NewIndexQuery()
			:InTable("duration", DURATION_ENUM_VALUES)
			:MinAndRelease("duration")
		if minDuration then
			nextExpire = floor(LibTSMService.GetTime() + DURATION_ENUM_VALUES[minDuration])
		end
	end

	-- Update expiring auctions
	local characterName = SessionInfo.GetCharacterName()
	if nextExpire and (private.storage[characterName] or math.huge) > nextExpire then
		private.SetNextExpire(nextExpire)
	elseif AuctionHouse.GetNumOwned() == 0 and private.storage[characterName] then
		private.SetNextExpire(nil)
	end
end

function private.PostAuctionHookHandler(duration)
	local days = nil
	if duration == 1 then
		days = 0.5
	elseif duration == 2 then
		days = 1
	elseif duration == 3 then
		days = 2
	end

	local characterName = SessionInfo.GetCharacterName()
	local nextExpire = floor(LibTSMService.GetTime() + (days * 24 * 60 * 60))
	if (private.storage[characterName] or math.huge) < nextExpire then
		return
	end
	private.SetNextExpire(nextExpire)
end

function private.SetNextExpire(nextExpire)
	private.storage[SessionInfo.GetCharacterName()] = nextExpire
	for _, callback in ipairs(private.callbacks) do
		callback()
	end
end
