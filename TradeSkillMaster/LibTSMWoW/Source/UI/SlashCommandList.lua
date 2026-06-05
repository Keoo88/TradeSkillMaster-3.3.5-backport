-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SlashCommandList = LibTSMWoW:Init("UI.SlashCommandList")



-- ============================================================================
-- Module Functions
-- ============================================================================

function SlashCommandList.Add(cmd, handler)
	local key = strupper(cmd)
	assert(not SlashCmdList[key])
	SlashCmdList[key] = handler
	_G["SLASH_"..key.."1"] = "/"..cmd
end
