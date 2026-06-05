-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Minimap = TSM.UI:NewPackage("Minimap") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Theme = TSM.LibTSMService:Include("UI.Theme")
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

function Minimap.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "minimapIcon")

	-- Create / register the minimap button
	local dataObj = LibDataBroker:NewDataObject("TradeSkillMaster", {
		type = "launcher",
		icon = "Interface\\Addons\\TradeSkillMaster\\Media\\TSM_Icon2",
		OnClick = function(_, button)
			if button ~= "LeftButton" then return end
			TSM.MainUI.Toggle()
		end,
		OnTooltipShow = function(tooltip)
			local cs = Theme.GetColor("INDICATOR_ALT"):GetTextColorPrefix()
			local ce = "|r"
			tooltip:AddLine("TradeSkillMaster "..TSM.LibTSMUtil.GetVersionStr())
			tooltip:AddLine(format(L["%sLeft-Click%s to open the main window"], cs, ce))
			tooltip:AddLine(format(L["%sDrag%s to move this button"], cs, ce))
		end,
	})
	LibDBIcon:Register("TradeSkillMaster", dataObj, private.settings.minimapIcon)
end
