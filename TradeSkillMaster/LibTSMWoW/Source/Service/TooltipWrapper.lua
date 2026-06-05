-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TooltipWrapper = LibTSMWoW:Init("TooltipWrapper")
local Guild = LibTSMWoW:Include("API.Guild")
local Merchant = LibTSMWoW:Include("API.Merchant")
local TradeSkill = LibTSMWoW:Include("API.TradeSkill")
local ExtraTooltip = LibTSMWoW:IncludeClassType("ExtraTooltip")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local private = {
	tooltipRegistry = {},
	hookedBattlepetGlobal = nil,
	tooltipMethodPrehooks = nil,
	tooltipMethodPosthooks = {},
	lastMailTooltipUpdate = nil,
	lastMailTooltipIndex = nil,
	embedTooltip = false,
	prepareTooltipFunc = nil,
	populateTooltipFunc = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and configures the tooltip wrapper code.
---@param prepareTooltipFunc fun(link: string, quantity: number): boolean Function which prepares the tooltip and returns whether or not it should be shown
---@param populateTooltipFunc fun(link: string, tooltip: GameTooltip, addItemName: boolean) Function which populates the tooltip
function TooltipWrapper.Load(prepareTooltipFunc, populateTooltipFunc)
	private.prepareTooltipFunc = prepareTooltipFunc
	private.populateTooltipFunc = populateTooltipFunc
	private.RegisterTooltip(GameTooltip)
	private.RegisterTooltip(ItemRefTooltip)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.BATTLE_PETS) then
		private.RegisterTooltip(BattlePetTooltip)
		private.RegisterTooltip(FloatingBattlePetTooltip)
	end
	local orig = OpenMailAttachment_OnEnter
	OpenMailAttachment_OnEnter = function(self, index)
		private.lastMailTooltipUpdate = private.lastMailTooltipUpdate or 0
		if private.lastMailTooltipIndex ~= index or private.lastMailTooltipUpdate + 0.1 < GetTime() then
			private.lastMailTooltipUpdate = GetTime()
			private.lastMailTooltipIndex = index
			orig(self, index)
		end
	end
end

---Sets whether or not the tooltip should be embedded.
---@param embed boolean Embed the tooltip or not
function TooltipWrapper.SetEmbedTooltip(embed)
	private.embedTooltip = embed
end

---Loads a 3rd-party item tooltip.
---@param tooltip GameTooltip The tooltip frame
---@param link string The item link
function TooltipWrapper.SetTooltipItem(tooltip, link)
	private.SetTooltipItem(tooltip, link)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RegisterTooltip(tooltip)
	local reg = {}
	reg.extraTip = ExtraTooltip.New(tooltip)
	private.tooltipRegistry[tooltip] = reg

	if private.IsBattlePetTooltip(tooltip) then
		if not private.hookedBattlepetGlobal then
			private.hookedBattlepetGlobal = true
			hooksecurefunc("BattlePetTooltipTemplate_SetBattlePet", private.OnTooltipSetBattlePet)
			hooksecurefunc("BattlePetToolTip_Show", private.OnBattlePetTooltipShow)
		end
		tooltip:HookScript("OnHide", private.OnTooltipCleared)
	else
		tooltip:HookScript("OnTooltipCleared", private.OnTooltipCleared)
		if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, private.OnTooltipSetItem)
		else
			tooltip:HookScript("OnTooltipSetItem", private.OnTooltipSetItem)
			for method, prehook in pairs(private.tooltipMethodPrehooks) do
				local posthook = private.tooltipMethodPosthooks[method]
				local orig = tooltip[method]
				tooltip[method] = function(...)
					prehook(...)
					local a, b, c, d, e, f, g, h, i, j, k = orig(...)
					posthook(...)
					return a, b, c, d, e, f, g, h, i, j, k
				end
			end
		end
	end
end

function private.IsBattlePetTooltip(tooltip)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.BATTLE_PETS) then
		return false
	end
	return tooltip == BattlePetTooltip or tooltip == FloatingBattlePetTooltip
end

function private.OnTooltipSetItem(tooltip, data)
	local reg = private.tooltipRegistry[tooltip]
	if not reg then
		return
	end
	if reg.hasItem then
		return
	end
	local itemLocation = ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) and data.guid and C_Item.GetItemLocation(data.guid)
	if itemLocation and itemLocation:IsBagAndSlot() then
		local info = C_Container.GetContainerItemInfo(itemLocation.bagID, itemLocation.slotIndex)
		if info then
			reg.quantity = info.stackCount
		end
	end

	tooltip:Show()
	local testName, item = tooltip:GetItem()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) and item and data.id and not strmatch(item, "item:"..data.id..":") then
		-- GetItem() seems to be broken for recipes on retail, so just look it up by ID
		item = "i:"..data.id
	elseif not item then
		item = reg.item
	elseif testName == "" then
		-- This is likely a case where :GetItem() is broken for recipes - detect and try to fix it
		if strmatch(item, "item:([0-9]*):") == "" then
			item = reg.item
		end
	end
	if not item then
		return
	end

	private.SetTooltipItem(tooltip, item)
end

function private.OnTooltipSetBattlePet(tooltip, data)
	local reg = private.tooltipRegistry[tooltip]
	if reg.hasItem then
		private.OnTooltipCleared(tooltip)
	end

	local link = reg.item
	if not link then
		-- Extract values from data
		local speciesID = data.speciesID
		local level = data.level
		local maxHealth = data.maxHealth
		local power = data.power
		local speed = data.speed
		local battlePetID = data.battlePetID or "0x0000000000000000"
		local name = data.name
		local customName = data.customName
		local breedQuality = data.breedQuality
		local colorCode = breedQuality == -1 and NORMAL_FONT_COLOR_CODE or (ITEM_QUALITY_COLORS[breedQuality] or ITEM_QUALITY_COLORS[0]).hex
		link = format("%s|Hbattlepet:%d:%d:%d:%d:%d:%d:%s|h[%s]|h|r", colorCode, speciesID, level, breedQuality, maxHealth, power, speed, battlePetID, customName or name)
	end

	private.SetTooltipItem(tooltip, link)
end

function private.OnTooltipCleared(tooltip)
	local reg = private.tooltipRegistry[tooltip]
	if reg.ignoreOnCleared then
		return
	end

	reg.extraTipUsed = nil
	reg.quantity = nil
	reg.hasItem = nil
	reg.item = nil
	reg.extraTip:Hide()
end

function private.OnBattlePetTooltipShow()
	local reg = private.tooltipRegistry[BattlePetTooltip]
	reg.extraTip:Show()
end

function private.SetTooltipItem(tooltip, link)
	local reg = private.tooltipRegistry[tooltip]
	local quantity = max(IsShiftKeyDown() and reg.quantity or 1, 1)
	if not private.prepareTooltipFunc(link, quantity) then
		return
	end

	reg.hasItem = true
	local useExtraTip = private.IsBattlePetTooltip(tooltip) or not private.embedTooltip

	-- Setup the extra tip if necessary
	if useExtraTip then
		reg.extraTip:Attach(tooltip)
		private.populateTooltipFunc(link, reg.extraTip, true)
	else
		private.populateTooltipFunc(link, tooltip, false)
	end

	-- Show the tooltip / extra tip as necessary
	if not private.IsBattlePetTooltip(tooltip) then
		tooltip:Show()
	end
	if useExtraTip then
		reg.extraTip:Show()
	end
end



-- ============================================================================
-- Hook Setup Code
-- ============================================================================

do
	local function PreHookHelper(self, quantityFunc, quantityOffset, ...)
		private.OnTooltipCleared(self)
		local reg = private.tooltipRegistry[self]
		reg.ignoreOnCleared = true
		if type(quantityFunc) == "number" then
			reg.quantity = quantityFunc
		elseif type(quantityOffset) == "string" then
			local data = quantityFunc(...)
			reg.quantity = data and data[quantityOffset] or nil
		else
			reg.quantity = select(quantityOffset, quantityFunc(...))
		end
		return reg
	end
	private.tooltipMethodPrehooks = {
		SetQuestItem = function(self, ...) PreHookHelper(self, GetQuestItemInfo, 3, ...) end,
		SetQuestLogItem = function(self, type, ...)
			local quantityFunc = type == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
			PreHookHelper(self, quantityFunc, 3, ...)
		end,
		SetRecipeReagentItem = function(self, ...)
			local quantity, itemLink = TradeSkill.GetMatInfoByDataSlotId(...)
			local reg = PreHookHelper(self, quantity)
			reg.item = itemLink
		end,
		SetRecipeResultItem = function(self, ...)
			private.OnTooltipCleared(self)
			local reg = private.tooltipRegistry[self]
			reg.ignoreOnCleared = true
			local lNum, hNum = TradeSkill.GetNumMade(...)
			-- The quantity can be a range, so use a quantity of 1 if so
			reg.quantity = lNum == hNum and lNum or 1
		end,
		SetTradeSkillItem = function(self, ...)
			private.OnTooltipCleared(self)
			local reg = private.tooltipRegistry[self]
			reg.ignoreOnCleared = true
			local lNum, hNum = TradeSkill.GetNumMade(...)
			-- The quantity can be a range, so use a quantity of 1 if so
			reg.quantity = lNum == hNum and lNum or 1
		end,
		SetBagItem = function(self, ...)
			PreHookHelper(self, C_Container.GetContainerItemInfo, "stackCount", ...)
		end,
		SetGuildBankItem = function(self, ...)
			local reg = PreHookHelper(self, Guild.GetItemCount, 1, ...)
			reg.item = Guild.GetItemLink(...)
		end,
		SetVoidItem = function(self, ...) PreHookHelper(self, 1) end,
		SetVoidDepositItem = function(self, ...) PreHookHelper(self, 1) end,
		SetVoidWithdrawalItem = function(self, ...) PreHookHelper(self, 1) end,
		SetInventoryItem = function(self, ...) PreHookHelper(self, GetInventoryItemCount, 1, ...) end,
		SetMerchantItem = function(self, ...)
			local reg = PreHookHelper(self, Merchant.GetItemInfo, 2, ...)
			reg.item = Merchant.GetItemLink(...)
		end,
		SetMerchantCostItem = function(self, ...) PreHookHelper(self, Merchant.GetCostItemInfo, 2, ...) end,
		SetBuybackItem = function(self, ...) PreHookHelper(self, Merchant.GetBuybackItemInfo, 2, ...) end,
		SetAuctionItem = (LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic()) and function(self, ...)
			local reg = PreHookHelper(self, GetAuctionItemInfo, 3, ...)
			reg.item = GetAuctionItemLink(...)
		end or nil,
		SetAuctionSellItem = (LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic()) and function(self, ...) PreHookHelper(self, GetAuctionSellItemInfo, 3, ...) end or nil,
		SetInboxItem = function(self, index) PreHookHelper(self, GetInboxItem, 4, index, 1) end,
		SetSendMailItem = function(self, ...) PreHookHelper(self, GetSendMailItem, 4, ...) end,
		SetLootItem = function(self, ...) PreHookHelper(self, GetLootSlotInfo, 3, ...) end,
		SetLootRollItem = function(self, ...) PreHookHelper(self, GetLootRollItemInfo, 3, ...) end,
		SetTradePlayerItem = function(self, ...) PreHookHelper(self, GetTradePlayerItemInfo, 3, ...) end,
		SetTradeTargetItem = function(self, ...) PreHookHelper(self, GetTradeTargetItemInfo, 3, ...) end,
		SetHyperlink = function(self, link)
			local reg = private.tooltipRegistry[self]
			private.OnTooltipCleared(self)
			reg.ignoreOnCleared = true
			reg.item = link
		end,
	}

	-- Populate all the posthooks
	local function TooltipMethodPostHook(self)
		private.tooltipRegistry[self].ignoreOnCleared = nil
	end
	for funcName in pairs(private.tooltipMethodPrehooks) do
		private.tooltipMethodPosthooks[funcName] = TooltipMethodPostHook
	end
	-- SetHyperlink is special
	private.tooltipMethodPosthooks.SetHyperlink = function(self)
		local reg = private.tooltipRegistry[self]
		reg.ignoreOnCleared = nil
	end
end
