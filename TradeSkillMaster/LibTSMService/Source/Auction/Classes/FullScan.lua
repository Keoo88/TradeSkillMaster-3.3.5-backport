-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local FullScan = LibTSMService:Init("Auction.FullScan")
local ChatMessage = LibTSMService:Include("UI.ChatMessage")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local StaticPopupDialog = LibTSMService:From("LibTSMWoW"):IncludeClassType("StaticPopupDialog")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local LibDeflate = LibStub("LibDeflate")
local private = {
	gameVersion = nil,
	encodingLookup = {},
	timer = nil,
	popupDialog = nil,
	state = "INITIALIZED",
	startTime = nil,
	scannedIndex = {},
	scanData = {},
}
local ENCODING_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"



-- ============================================================================
-- Module Loading
-- ============================================================================

FullScan:OnModuleLoad(function()
	if ClientInfo.IsVanillaClassic() then
		if SessionInfo.IsSeasonOfDiscovery() then
			private.gameVersion = "Season of Discovery"
		elseif SessionInfo.IsHardcore() then
			private.gameVersion = "Classic Era - Hardcore"
		elseif SessionInfo.IsFresh() then
			private.gameVersion = "Classic Era - Fresh"
		else
			private.gameVersion = "Classic Era"
		end
	elseif ClientInfo.IsBCClassic() and SessionInfo.IsFresh() then
		private.gameVersion = "Classic Era - Fresh"
	elseif ClientInfo.IsWrathClassic() then
		private.gameVersion = "Wrath"
		private.popupDialog = StaticPopupDialog.New()
			:SetText("Start Scan?")
			:SetYesNo()
			:HideOnEscape()
			:SetScript("OnAccept", function()
				AuctionHouse.StartGetAllScan()
				ChatMessage.PrintUserRaw("Started full scan.")
			end)
	elseif ClientInfo.IsPandaClassic() then
		private.gameVersion = "Wrath"
		private.popupDialog = StaticPopupDialog.New()
			:SetText("Start Scan?")
			:SetYesNo()
			:HideOnEscape()
			:SetScript("OnAccept", function()
				AuctionHouse.StartGetAllScan()
				ChatMessage.PrintUserRaw("Started full scan.")
			end)
	else
		-- Ignore for retail
		return
	end
	private.timer = DelayTimer.New("FULL_SCAN_LOOP", private.ScannerLoop)
	Event.Register("AUCTION_HOUSE_CLOSED", private.HandleAuctionHouseClosed)
	for i = 1, #ENCODING_ALPHABET do
		private.encodingLookup[i - 1] = strsub(ENCODING_ALPHABET, i, i)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Enables the full scan hook.
function FullScan.Enable()
	if private.gameVersion then
		Event.Register("AUCTION_HOUSE_SHOW", private.HandleAuctionHouseShow)
		AuctionHouse.SecureHookGetAllScan(private.StartScan)
	end
end

---Gets the encoded scan data.
---@return string? data
---@return number? scanTime
function FullScan.GetData()
	if Table.Count(private.scanData) <= 50 then
		return nil
	end
	return private.EncodeScanData(), private.startTime
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StartScan()
	if private.state ~= "INITIALIZED" and private.state ~= "DONE" then
		return
	end
	Log.Info("Starting scan")
	wipe(private.scannedIndex)
	wipe(private.scanData)
	private.state = "STARTED"
	private.startTime = floor(LibTSMService.GetTime())
	private.timer:RunForTime(1)
	-- Auctionator unregisters other frames from events while it processes a scan - so we create a frame to register for all events
	Event.RegisterAllEvents(private.HandleAllEvents)
end

function private.HandleAuctionHouseShow()
	if private.state ~= "INITIALIZED" or not private.popupDialog then
		return
	end
	private.popupDialog:Show()
end

function private.HandleAuctionHouseClosed()
	if private.state ~= "INITIALIZED" then
		private.state = "INTERRUPTED"
	end
end

function private.HandleAllEvents(event)
	if private.state ~= "STARTED" then
		Event.UnregisterAllEvents(private.HandleAllEvents)
	end
	if event == "AUCTION_ITEM_LIST_UPDATE" or event == "REPLICATE_ITEM_LIST_UPDATE" then
		private.state = "GOT_UPDATE"
	end
end

function private.ScannerLoop()
	if private.state == "STARTED" then
		-- Waiting for AUCTION_ITEM_LIST_UPDATE event
		private.timer:RunForTime(0.5)
	elseif private.state == "GOT_UPDATE" then
		-- Wait another 0.5 seconds and then start scanning
		private.state = "SCANNING"
		private.timer:RunForTime(0.5)
	elseif private.state == "SCANNING" then
		-- Keep trying to scan any data we don't yet have
		local hasInvalid = false
		local numScanned = 0
		for i = 1, AuctionHouse.GetNumGetAllAuctions() do
			if not private.scannedIndex[i] then
				local isValid = private.ScanAuction(i)
				if isValid then
					private.scannedIndex[i] = true
					numScanned = numScanned + 1
				else
					hasInvalid = true
				end
			end
			if numScanned == 500 then
				break
			end
		end
		if hasInvalid or numScanned ~= 0 then
			private.timer:RunForTime(numScanned == 500 and 0.01 or 1)
		else
			private.state = "DONE"
			Log.Info("Finished scanning (%s items)", Table.Count(private.scanData))
			if private.popupDialog then
				ChatMessage.PrintUserRaw("Finished full scan.")
			end
		end
	end
end

function private.ScanAuction(index)
	local itemLink, stackSize, buyout = AuctionHouse.GetGetAllResult(index)
	local itemString = itemLink and ItemString.Get(itemLink)
	if not itemString or not stackSize then
		return false
	end
	if not buyout or buyout == 0 then
		return true
	end
	buyout = floor(buyout / stackSize)
	private.scanData[itemString] = private.scanData[itemString] or {}
	tinsert(private.scanData[itemString], {buyout, stackSize, index})
	return true
end

function private.EncodeScanData()
	local result = {}
	tinsert(result, strjoin(",", private.startTime, private.gameVersion, SessionInfo.GetRegion(), SessionInfo.GetRealmName(), SessionInfo.GetFactionName(), SessionInfo.GetCharacterName()))
	for itemString, data in pairs(private.scanData) do
		-- Sort all the data by buyout
		Table.Sort(data, private.ScanDataSortHelper)
		local itemData = {}
		local i = 1
		while i <= #data do
			-- Add up all the quantities at this buyout price
			local buyout, quantity = unpack(data[i])
			i = i + 1
			while i <= #data and data[i][1] == buyout do
				quantity = quantity + data[i][2]
				i = i + 1
			end
			if quantity > 1 then
				tinsert(itemData, strjoin("x", buyout, quantity))
			else
				tinsert(itemData, buyout)
			end
		end
		tinsert(result, strjoin(",", itemString, unpack(itemData)))
	end
	return private.EncodeBase64(LibDeflate:CompressDeflate(table.concat(result, "\n")))
end

function private.ScanDataSortHelper(a, b)
	local aBuyout = a[1]
	local bBuyout = b[1]
	if aBuyout ~= bBuyout then
		return aBuyout < bBuyout
	end
	return a[3] < b[3]
end

function private.EncodeBase64(data)
	local encodedChars = {}
	local numEncodedChars = 0
	for i = 1, ceil(#data / 3) do
		local b1, b2, b3 = strbyte(data, (i - 1) * 3 + 1, i * 3)
		local b1Lower = b1 % 4
		encodedChars[numEncodedChars + 1] = private.encodingLookup[(b1 - b1Lower) / 4]
		if b2 then
			local b2Lower = b2 and b2 % 16 or nil
			encodedChars[numEncodedChars + 2] = private.encodingLookup[b1Lower * 16 + (b2 - b2Lower) / 16]
			if b3 then
				local b3Part2 = b3 % 64
				encodedChars[numEncodedChars + 3] = private.encodingLookup[b2Lower * 4 + (b3 - b3Part2) / 64]
				encodedChars[numEncodedChars + 4] = private.encodingLookup[b3Part2]
			else
				encodedChars[numEncodedChars + 3] = private.encodingLookup[b2Lower * 4]
				encodedChars[numEncodedChars + 4] = "="
			end
		else
			encodedChars[numEncodedChars + 2] = private.encodingLookup[b1Lower * 16]
			encodedChars[numEncodedChars + 3] = "="
			encodedChars[numEncodedChars + 4] = "="
		end
		numEncodedChars = numEncodedChars + 4
	end
	return table.concat(encodedChars)
end
