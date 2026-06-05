-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Expiring = LibTSMService:Init("Mail.Expiring")
local Scanner = LibTSMService:Include("Mail.Scanner")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	expiringStorage = nil,
	callbacks = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param expiringData table<string,number> Expiring time by character
function Expiring.Load(expiringData)
	private.expiringStorage = expiringData
	Scanner.RegisterMailCallback(private.HandleMailCallback)
end

---Registers a callback for when the expiring time changes.
---@param func fun()
function Expiring.RegisterCallback(func)
	tinsert(private.callbacks, func)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleMailCallback()
	-- Update the expiration time
	local nextExpiration = Scanner.NewMailQuery()
		:Select("expires")
		:GreaterThan("itemCount", 0)
		:GreaterThan("money", 0)
		:OrderBy("expires", true)
		:GetFirstResultAndRelease()
	local playerName = SessionInfo.GetCharacterName()
	private.expiringStorage[playerName] = nextExpiration and floor(LibTSMService.GetTime() + (nextExpiration * 24 * 60 * 60)) or nil
	for _, callback in ipairs(private.callbacks) do
		callback()
	end
end
