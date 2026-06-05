-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local SessionInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMUI:From("LibTSMService"):Include("Auction")
local UIElements = LibTSMUI:Include("Util.UIElements")
local Tooltip = LibTSMUI:Include("Tooltip")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local PlayerGoldText = UIElements.Define("PlayerGoldText", "Button")
PlayerGoldText:_ExtendStateSchema()
	:UpdateFieldDefault("justifyH", "RIGHT")
	:UpdateFieldDefault("font", "TABLE_TABLE1")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PlayerGoldText:Release()
	self._settings = nil
	self.__super:Release()
end

---Sets the settings object (should have `money`, `showTotalMoney`, `regionWide`, `warbankMoney` keys).
---@param settings SettingsView
function PlayerGoldText:SetSettings(settings)
	assert(settings and not self._settings)
	self._settings = settings
	self:SetTooltip(self:__closure("_GetTooltip"))
	self:SetTextPublisher(settings:PublisherForKeys("money", "showTotalMoney", "regionWide", "warbankMoney")
		:MapWithFunction(private.SettingsToText)
	)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function PlayerGoldText.__private:_GetTooltip()
	local tooltipLines = TempTable.Acquire()
	local playerMoney = self._settings.money
	local total = playerMoney
	tinsert(tooltipLines, private.GetTooltipLine(SessionInfo.GetCharacterName(), playerMoney))
	local numPosted, numSold, postedGold, soldGold = Auction.GetSummaryInfo()
	if numPosted then
		tinsert(tooltipLines, private.GetTooltipLine(format("  "..L["%s Sold Auctions"], numSold), soldGold))
		tinsert(tooltipLines, private.GetTooltipLine(format("  "..L["%s Posted Auctions"], numPosted), postedGold))
	end
	for _, money, character, factionrealm in self._settings:AccessibleValueIterator("money") do
		if money > 0 and not SessionInfo.IsPlayer(character, factionrealm) then
			character = SessionInfo.FormatCharacterName(character, factionrealm)
			tinsert(tooltipLines, private.GetTooltipLine(character, money))
			total = total + money
		end
	end
	if LibTSMUI.IsRetail() then
		local warbankMoney = self._settings.warbankMoney
		tinsert(tooltipLines, private.GetTooltipLine(L["Warbank"], warbankMoney))
		total = total + warbankMoney
	end
	tinsert(tooltipLines, 1, private.GetTooltipLine(L["Total Gold"], total))
	return strjoin("\n", TempTable.UnpackAndRelease(tooltipLines))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SettingsToText(settings)
	local amount = settings.money
	if settings.showTotalMoney then
		for _, money, character, factionrealm in settings:AccessibleValueIterator("money") do
			if money > 0 and not SessionInfo.IsPlayer(character, factionrealm) then
				amount = amount + money
			end
		end
		amount = amount + settings.warbankMoney
	end
	return Money.ToStringForUI(amount)
end

function private.GetTooltipLine(label, value)
	return strjoin(Tooltip.GetSepChar(), label..":", Money.ToStringForUI(value))
end
