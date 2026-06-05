-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SoundAlert = LibTSMWoW:Init("UI.SoundAlert")
SoundAlert.NO_SOUND_KEY = "TSM_NO_SOUND" -- This can never change
local private = {
	keys = {},
}
local KIT_IDS = {
	["AuctionWindowOpen"] = 5274,
	["AuctionWindowClose"] = 5275,
	["alarmclockwarning3"] = 12889,
	["UI_AutoQuestComplete"] = 23404,
	["HumanExploration"] = 4140,
	["Fishing Reel in"] = 3407,
	["LevelUp"] = 888,
	["MapPing"] = 3175,
	["MONEYFRAMEOPEN"] = 891,
	["IgPlayerInviteAccept"] = 880,
	["QUESTADDED"] = 618,
	["QUESTCOMPLETED"] = 878,
	["UI_QuestObjectivesComplete"] = 26905,
	["RaidWarning"] = 8959,
	["ReadyCheck"] = 8960,
	["UnwrapGift"] = 64329,
}
local CUSTOM_KEYS = {
	["TSM_CASH_REGISTER"] = "Interface\\Addons\\TradeSkillMaster\\Media\\register.mp3"
}
---@alias TSMSoundKey SoundKey|"TSM_NO_SOUND"|"TSM_CASH_REGISTER"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over the sound keys.
---@return fun(): number, string @Iteartor with fields: `index`, `key`
function SoundAlert.KeyIterator()
	if #private.keys == 0 then
		tinsert(private.keys, SoundAlert.NO_SOUND_KEY)
		for key in pairs(KIT_IDS) do
			tinsert(private.keys, key)
		end
		for key in pairs(CUSTOM_KEYS) do
			tinsert(private.keys, key)
		end
	end
	return ipairs(private.keys)
end

---Plays a sound to alert the user.
---@param soundKey TSMSoundKey
function SoundAlert.Play(soundKey)
	if soundKey == SoundAlert.NO_SOUND_KEY then
		-- do nothing
	elseif CUSTOM_KEYS[soundKey] then
		PlaySoundFile(CUSTOM_KEYS[soundKey], "Master")
		FlashClientIcon()
	elseif KIT_IDS[soundKey] then
		PlaySound(KIT_IDS[soundKey], "Master")
		FlashClientIcon()
	else
		error("Invalid sound key: "..tostring(soundKey))
	end
end
