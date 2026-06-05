-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Trade = TSM.Accounting:NewPackage("Trade") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Event = TSM.LibTSMWoW:Include("Service.Event")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local StaticPopupDialog = TSM.LibTSMWoW:IncludeClassType("StaticPopupDialog")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local private = {
	settings = nil,
	tradeInfo = nil,
	popupContext = nil,
	popupDialog = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Trade.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "accountingOptions", "trackTrades")
		:AddKey("global", "accountingOptions", "autoTrackTrades")
	Event.Register("TRADE_ACCEPT_UPDATE", private.OnAcceptUpdate)
	Event.Register("UI_INFO_MESSAGE", private.OnChatMsg)
end



-- ============================================================================
-- Trade Functions
-- ============================================================================

function private.OnAcceptUpdate(_, player, target)
	if (player == 1 or target == 1) and not (GetTradePlayerItemLink(7) or GetTradeTargetItemLink(7)) then
		-- update tradeInfo
		private.tradeInfo = { player = {}, target = {} }
		private.tradeInfo.player.money = tonumber(GetPlayerTradeMoney())
		private.tradeInfo.target.money = tonumber(GetTargetTradeMoney())
		private.tradeInfo.target.name = UnitName("NPC")

		for i = 1, 6 do
			local targetLink = GetTradeTargetItemLink(i)
			local _, _, targetCount = GetTradeTargetItemInfo(i)
			if targetLink then
				tinsert(private.tradeInfo.target, { itemString = ItemString.Get(targetLink), count = targetCount })
			end

			local playerLink = GetTradePlayerItemLink(i)
			local _, _, playerCount = GetTradePlayerItemInfo(i)
			if playerLink then
				tinsert(private.tradeInfo.player, { itemString = ItemString.Get(playerLink), count = playerCount })
			end
		end
	else
		private.tradeInfo = nil
	end
end

function private.OnChatMsg(_, msg)
	if not private.settings.trackTrades then
		return
	end
	if msg == LE_GAME_ERR_TRADE_COMPLETE and private.tradeInfo then
		-- trade went through
		local tradeType, itemString, count, money = nil, nil, nil, nil
		if private.tradeInfo.player.money > 0 and #private.tradeInfo.player == 0 and private.tradeInfo.target.money == 0 and #private.tradeInfo.target > 0 then
			-- player bought items
			for i = 1, #private.tradeInfo.target do
				local data = private.tradeInfo.target[i]
				if not itemString then
					itemString = data.itemString
					count = data.count
				elseif itemString == data.itemString then
					count = count + data.count
				else
					return
				end
			end
			tradeType = "buy"
			money = private.tradeInfo.player.money
		elseif private.tradeInfo.player.money == 0 and #private.tradeInfo.player > 0 and private.tradeInfo.target.money > 0 and #private.tradeInfo.target == 0 then
			-- player sold items
			for i = 1, #private.tradeInfo.player do
				local data = private.tradeInfo.player[i]
				if not itemString then
					itemString = data.itemString
					count = data.count
				elseif itemString == data.itemString then
					count = count + data.count
				else
					return
				end
			end
			tradeType = "sale"
			money = private.tradeInfo.target.money
		end

		if not tradeType or not itemString or not count then
			return
		end
		local insertInfo = TempTable.Acquire()
		insertInfo.type = tradeType
		insertInfo.itemString = itemString
		insertInfo.price = money / count
		insertInfo.count = count
		insertInfo.name = private.tradeInfo.target.name
		local gotText, gaveText = nil, nil
		if tradeType == "buy" then
			gotText = format("%sx%d", ItemInfo.GetLink(itemString), count)
			gaveText = Money.ToStringExact(money)
		elseif tradeType == "sale" then
			gaveText = format("%sx%d", ItemInfo.GetLink(itemString), count)
			gotText = Money.ToStringExact(money)
		else
			error("Invalid tradeType: "..tostring(tradeType))
		end

		if private.settings.autoTrackTrades then
			private.DoInsert(insertInfo)
			TempTable.Release(insertInfo)
		else
			if private.popupContext then
				-- popup already visible so ignore this
				TempTable.Release(insertInfo)
				return
			end
			private.popupContext = insertInfo
			if not private.popupDialog then
				private.popupDialog = StaticPopupDialog.New()
					:SetYesNo()
					:HideOnEscape()
					:SetScript("OnAccept", function()
						private.DoInsert(private.popupContext)
						TempTable.Release(private.popupContext)
						private.popupContext = nil
					end)
					:SetScript("OnCancel", function()
						TempTable.Release(private.popupContext)
						private.popupContext = nil
					end)
			end
			private.popupDialog:SetText(format(L["TSM detected that you just traded %s to %s in return for %s. Would you like Accounting to store a record of this trade?"], gaveText, insertInfo.name, gotText))
			private.popupDialog:Show()
		end
	end
end

function private.DoInsert(info)
	if info.type == "sale" then
		TSM.Accounting.Transactions.InsertTradeSale(info.itemString, info.count, info.price, info.name)
	elseif info.type == "buy" then
		TSM.Accounting.Transactions.InsertTradeBuy(info.itemString, info.count, info.price, info.name)
	else
		error("Unknown type: "..tostring(info.type))
	end
end
