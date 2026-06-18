if __TSM_ClassicAPI_SKIP then return end
local Private = __TSM_ClassicAPI_Private

-- Texture Path
Private.TEXTURE_PATH = "Interface\\AddOns\\!!!ClassicAPI\\Texture\\"

-- Scan Tooltip
local Tooltip = CreateFrame("GameTooltip", "CAPI_ScanTooltip")
Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
Tooltip:AddFontStrings(Tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"), Tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
Private.Tooltip = Tooltip

-- General Event
Tooltip:SetScript("OnEvent", function(Self, Event)
	-- [Unit.lua:C_UnitInRange] Force client to cache Vial of the Sunwell
	if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_CLASSIC ) then
		local _, RangeItemCached = GetItemInfo(34471)
		if ( not RangeItemCached ) then
			ItemEventListener:AddCallback(34471, Private.Void)
		end
	end

	ItemEventListener:Init()
	Self:UnregisterEvent(Event)
	Self:SetScript("OnEvent", nil)
end)
Tooltip:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Common Functions
function Private.Void()
	-- To the nether!
end

function Private.True()
	return true
end

function Private.False()
	return false
end

function Private.Zero()
	return 0
end

--[[ SAFETY STUBS ]]
-- Modern API namespaces that do not exist on 3.3.5a. TSM only reaches these
-- through short-circuit guards today, but defining inert stubs removes the
-- fragility if any call site forgets the guard. We never override an existing
-- definition (standalone !!!ClassicAPI addon or a real namespace), and we reuse
-- the shared Private.* helpers so return types stay consistent.

-- C_PetJournal.GetNumPets() -> numPets, numOwned. No pet journal on 3.3.5a.
_G.C_PetJournal = _G.C_PetJournal or {}
if ( not _G.C_PetJournal.GetNumPets ) then
	_G.C_PetJournal.GetNumPets = function() return 0, 0 end
end

-- C_Seasons.HasActiveSeason() -> bool. WotLK realms are never seasonal.
_G.C_Seasons = _G.C_Seasons or {}
if ( not _G.C_Seasons.HasActiveSeason ) then
	_G.C_Seasons.HasActiveSeason = Private.False
end

--[[ MISCELLANEOUS ]]

-- [LFD_ERROR_FIX] Workaround long-standing client/server error.
local LFDCooldown = LFDQueueFrameCooldownFrame
if ( LFDCooldown ) then
	LFDCooldown:UnregisterEvent("UNIT_AURA")
	LFDCooldown:UnregisterEvent("PARTY_MEMBERS_CHANGED")
	LFDQueueFrame:HookScript("OnShow", LFDQueueFrameRandomCooldownFrame_Update)
end