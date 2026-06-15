local _, Private = ...

local _G = _G
local Mod = mod
local Next = next
local PCall = pcall
local Error = error
local StrLen = strlen
local Ceil = math.ceil
local Sub = string.sub
local GetTime = GetTime
local GetCVar = GetCVar
local String = tostring
local Floor = math.floor
local GSub = string.gsub
local SecureCall = securecall
local GetMapInfo = GetMapInfo
local Reverse = string.reverse
local GetRealmName = GetRealmName
local GetAddOnInfo = GetAddOnInfo
local IsAddOnLoaded = IsAddOnLoaded
local GetInstanceInfo = GetInstanceInfo
local IsAddOnLoadOnDemand = IsAddOnLoadOnDemand

local FIRST_NUMBER_CAP = FIRST_NUMBER_CAP
local SECOND_NUMBER_CAP = SECOND_NUMBER_CAP
local LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR

function AnimateTexCoords(Self, Width, Height, FrameW, FrameH, NumFrames, Elapsed, Throttle)
	-- This exists, we just optimize it.
	Throttle = Throttle or 0.1

	if ( not Self.frame ) then
		Self.frame = 0
		Self.throttleTimer = 0
		Self.maxFrames = NumFrames

		Self.numColumns = Floor(Width / FrameW)
		Self.columnWidth = FrameW / Width
		Self.rowHeight = FrameH / Height
	end

	Self.throttleTimer = Self.throttleTimer + Elapsed

	if ( Self.throttleTimer >= Throttle ) then
		local NewFrame = (Self.frame + 1) % Self.maxFrames
		Self.frame = NewFrame
		Self.throttleTimer = 0

		local Column = NewFrame % Self.numColumns
		local Row = Floor(NewFrame / Self.numColumns)

		local Left = Column * Self.columnWidth
		local Right = Left + Self.columnWidth
		local Top = Row * Self.rowHeight
		local Bottom = Top + Self.rowHeight

		Self:SetTexCoord(Left, Right, Top, Bottom)
	end
end

function GetTexCoordsForRoleSmallCircle(Role)
	if ( Role == "TANK" ) then
		return 0, 19/64, 22/64, 41/64
	elseif ( Role == "HEALER" ) then
		return 20/64, 39/64, 1/64, 20/64
	elseif ( Role == "DAMAGER" ) then
		return 20/64, 39/64, 22/64, 41/64
	else
		Error("Unknown role: "..String(Role), 2)
	end
end

local function secureexecutenext(Table, Prev, Func, ...)
	local Key, Value = Next(Table, Prev)
	if ( Key ~= nil ) then
		PCall(Func, Key, Value, ...)  -- Errors are silently discarded!
	end
	return Key
end

function secureexecuterange(Table, Func, ...)
	local Key = nil
	repeat
		Key = SecureCall(secureexecutenext, Table, Key, Func, ...)
	until Key == nil
end

function securecallfunction(Func, ...)
	return SecureCall(Func, ...)
end

function GetAddOnEnableState(Character, Index)
	-- Can't get per-char addons, doing what we can.
	local _, _, _, Enabled, Loadable = GetAddOnInfo(Index)
	return (Enabled) and 2 or 0
end

function IsAddonVersionCheckEnabled()
	return GetCVar("checkAddonVersion") == "1"
end

function C_GetAddOnInfo(Index)
	local Name, Title, Notes, Enabled, Loadable, Reason, Security = GetAddOnInfo(Index)
	local NewVersion = nil

	-- Missing "Reason" values: BANNED", "CORRUPT", "DEMAND_LOADED", "INCOMPATIBLE"
	if ( Loadable and not IsAddOnLoaded(Index) and IsAddOnLoadOnDemand(Index) ) then
		Reason = "DEMAND_LOADED"
		Loadable = nil
	end

	return Name, Title, Notes, Loadable, Reason, Security, NewVersion
end

function HasOverrideActionBar()
	return _G.BonusActionBarFrame:IsShown()
end

function HasVehicleActionBar()
	return _G.VehicleMenuBar:IsShown()
end

function GetDifficultyInfo(ID)
	--return "Normal", "party", false, false, false, false, nil
end

function C_GetInstanceInfo()
	local InstanceName, InstanceType, DifficultyIndex, DifficultyName, MaxPlayers, DynamicDifficulty, IsDynamic = GetInstanceInfo()

	if ( InstanceType == "pvp"  ) then
		local Map = GetMapInfo() -- This relies on WatchFrame calling SetMapToCurrentZone() on zone changes.
		if ( Map == "AlteracValley" or Map == "IsleofConquest" or Map == "LakeWintergrasp" ) then
			MaxPlayers = 40
		elseif ( Map == "ArathiBasin" or Map == "NetherstormArena" or Map == "StrandoftheAncients" ) then
			MaxPlayers = 15
		elseif ( Map == "WarsongGulch" ) then
			MaxPlayers = 10
		end
	end

	return InstanceName, InstanceType, DifficultyIndex, DifficultyName, MaxPlayers, DynamicDifficulty, IsDynamic
end

function GetServerTime()
	return GetTime() -- Sadly, we have to still use client time.
end

function GetNormalizedRealmName()
	local Name = GSub(GetRealmName(), "[-%s]", "")
	return Name
end

function Ambiguate(FullName, Context)
	-- TODO: Make diff context work properly.
	return FullName
end

function CombatLogGetCurrentEventInfo(Timestamp, SubEvent, SrcGUID, SrcName, SrcFlag, DstGUID, DstName, DstFlag, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12)
	if ( not Timestamp ) then return end

	-- Modern payload (Missing)
	local HideCaster, SrcRaidFlag, DstRaidFlag = false, nil, nil

	-- Note: Blizzard could have changed order of payload from 9th onwards.
	return Timestamp, SubEvent, HideCaster, SrcGUID, SrcName, SrcFlag, SrcRaidFlag, DstGUID, DstName, DstFlag, DstRaidFlag, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12
end

function AbbreviateLargeNumbers(Value, Breakup)
	local StrLen = StrLen(Value)
	local RetString = Value

	if ( StrLen > 8 ) then
		RetString = Sub(Value, 1, -7)..SECOND_NUMBER_CAP
	elseif ( StrLen > 5 ) then
		RetString = Sub(Value, 1, -4)..FIRST_NUMBER_CAP
	elseif (StrLen > 3 ) then
		RetString = BreakUpLargeNumbers(Value, Breakup)
	end

	return RetString
end

function BreakUpLargeNumbers(Value, Breakup)
	local RetString = ""

	if ( Value < 1000 ) then
		if ( (Value - Floor(Value)) == 0) then
			return Value
		end

		local Decimal = (Floor(Value*100))
		RetString = Sub(Decimal, 1, -3)
		RetString = RetString..DECIMAL_SEPERATOR
		RetString = RetString..Sub(Decimal, -2)

		return RetString
	end

	Value = Floor(Value)

	local StrLen = StrLen(Value)
	if ( Breakup ) then
		if ( StrLen > 6 ) then
			RetString = Sub(Value, 1, -7)..LARGE_NUMBER_SEPERATOR
		end
		if ( StrLen > 3 ) then
			RetString = RetString..Sub(Value, -6, -4)..LARGE_NUMBER_SEPERATOR
		end
		RetString = RetString..Sub(Value, -3, -1)
	else
		RetString = Value
	end

	return RetString
end

function FormatLargeNumber(Amount)
	Amount = GSub(Reverse(GSub(Reverse(String(Amount)), "(%d%d%d)", "%1,")), "^,", "")
	return Amount
end

local InitalGTPSCall
function GetTimePreciseSec()
	local Time = GetTime()
	if InitalGTPSCall == nil then InitalGTPSCall = Time end
	return Time - InitalGTPSCall
end

function BankFrame_Open()
	_G.BankFrame_OnEvent(_G["BankFrame"], "BANKFRAME_OPENED")
end

function MerchantFrame_MerchantShow()
	_G.MerchantFrame_OnEvent(_G["MerchantFrame"], "MERCHANT_SHOW")
end

function MerchantFrame_MerchantClosed()
	_G.MerchantFrame_OnEvent(_G["MerchantFrame"], "MERCHANT_CLOSED")
end

function TabardFrame_Open()
	_G.TabardFrame_OnEvent(_G["TabardFrame"], "OPEN_TABARD_FRAME")
end

function MailFrame_Show()
	_G.MailFrame_OnEvent(_G["MailFrame"], "MAIL_SHOW")
end

function MailFrame_Hide()
	_G.MailFrame_OnEvent(_G["MailFrame"], "MAIL_CLOSED")
end

_G.PostAuction = _G.StartAuction
_G.InGlue = Private.False
_G.PassClickToParent = Private.Void