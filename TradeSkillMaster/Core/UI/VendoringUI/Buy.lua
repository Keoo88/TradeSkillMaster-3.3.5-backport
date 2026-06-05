-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Buy = TSM.UI.VendoringUI:NewPackage("Buy") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Merchant = TSM.LibTSMWoW:Include("API.Merchant")
local Guild = TSM.LibTSMWoW:Include("API.Guild")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local Vendor = TSM.LibTSMService:Include("Vendor")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	filterText = "",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Buy.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "vendoringUIContext", "buyScrollingTable")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
	TSM.UI.VendoringUI.RegisterTopLevelPage(L["Buy"], private.GetFrame)
end

function Buy.UpdateCurrency(frame)
	if not Merchant.GetCurrencies() or frame:GetSelectedNavButton() ~= L["Buy"] then
		return
	end
	frame:GetElement("content.buy.footer.altCost")
		:SetText(private.GetCurrencyText())
	frame:GetElement("content.buy.footer")
		:Draw()
end



-- ============================================================================
-- Buy UI
-- ============================================================================

function private.GetFrame()
	UIUtils.AnalyticsRecordPathChange("vendoring", "buy")
	private.filterText = ""
	local altCost = ClientInfo.IsRetail() and Merchant.GetCurrencies()
	local frame = UIElements.New("Frame", "buy")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "filters")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Input", "searchInput")
				:SetMargin(0, 8, 0, 0)
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:AllowItemInsert()
				:SetHintText(L["Search Vendor"])
				:SetScript("OnValueChanged", private.InputOnValueChanged)
			)
			:AddChild(UIElements.New("Button", "filterBtn")
				:SetWidth("AUTO")
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_BODY3_MEDIUM")
				:SetText(FILTERS)
				-- TODO
				-- :SetScript("OnClick", private.FilterButtonOnClick)
			)
			:AddChild(UIElements.New("Button", "filterBtnIcon")
				:SetBackgroundAndSize("iconPack.14x14/Filter")
				-- TODO
				-- :SetScript("OnClick", private.FilterButtonOnClick)
			)
		)
		:AddChild(UIElements.New("VendorBuyScrollTable", "items")
			:SetSettings(private.settings, "buyScrollingTable")
			:SetQuery(Vendor.NewScannerQuery()
				:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
				:VirtualField("itemLevel", "number", ItemInfo.GetItemLevel, "itemString", -1)
			)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "gold")
				:SetLayout("HORIZONTAL")
				:SetWidth(166)
				:SetMargin(0, 8, 0, 0)
				:SetPadding(4)
				:AddChild(UIElements.New("PlayerGoldText", "text")
					:SetSettings(private.settings)
				)
			)
			:AddChild(UIElements.New("VerticalLine", "line")
				:SetHeight(22)
				:SetMargin(0, 8, 0, 0)
			)
			:AddChild(UIElements.New("Button", "altCost")
				:SetWidth("AUTO")
				:SetMargin(0, 16, 0, 0)
				:SetFont("TABLE_TABLE1")
				:SetText(private.GetCurrencyText())
				:SetTooltip(altCost and "currency:"..altCost or nil)
			)
			:AddChild(UIElements.New("ActionButton", "repairBtn")
				:SetDisabled(not Vendor.NeedsRepair())
				:SetText(L["Repair"])
				:SetModifierText(L["Repair from Guild Bank"], "ALT")
				:SetTooltip(private.GetRepairTooltip)
				:SetScript("OnClick", private.RepairOnClick)
			)
		)
	if not altCost then
		frame:GetElement("footer.line")
			:Hide()
		frame:GetElement("footer.altCost")
			:Hide()
	end
	return frame
end

function private.GetRepairTooltip()
	local tooltipLines = TempTable.Acquire()
	local repairAllCost, canRepair = GetRepairAllCost()
	if canRepair and repairAllCost > 0 then
		tinsert(tooltipLines, REPAIR_ALL_ITEMS)
		if IsAltKeyDown() then
			local amount = Guild.GetWidthdrawMoney()
			local guildBankMoney = Guild.GetMoney()
			if amount == -1 then
				amount = guildBankMoney
			else
				amount = min(amount, guildBankMoney)
			end
			tinsert(tooltipLines, GUILDBANK_REPAIR)
			tinsert(tooltipLines, Money.ToStringForUI(amount))
			if repairAllCost > amount then
				local personalAmount = repairAllCost - amount
				local personalMoney = GetMoney()
				if personalMoney >= personalAmount then
					tinsert(tooltipLines, GUILDBANK_REPAIR_PERSONAL)
					tinsert(tooltipLines, Money.ToStringForUI(personalAmount))
				else
					tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(GUILDBANK_REPAIR_INSUFFICIENT_FUNDS))
				end
			end
		else
			tinsert(tooltipLines, Money.ToStringForUI(repairAllCost))
			local personalMoney = GetMoney()
			if repairAllCost > personalMoney then
				tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(GUILDBANK_REPAIR_INSUFFICIENT_FUNDS))
			end
			tinsert(tooltipLines, L["Hold ALT to repair from the guild bank."])
		end
	end
	return strjoin("\n", TempTable.UnpackAndRelease(tooltipLines))
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.InputOnValueChanged(input)
	local nameFilter = input:GetValue()
	if nameFilter == private.filterText then
		return
	end
	private.filterText = nameFilter
	nameFilter = String.Escape(nameFilter)
	input:GetElement("__parent.__parent.items"):SetFilters(nameFilter ~= "" and nameFilter or nil)
end

function private.GetCurrencyText()
	local name, amount, texturePath = "", nil, nil
	if ClientInfo.IsRetail() then
		local firstCurrency = Merchant.GetCurrencies()
		if firstCurrency then
			local info = C_CurrencyInfo.GetCurrencyInfo(firstCurrency)
			name = info.name
			amount = info.quantity
			texturePath = info.iconFileID
		end
	end
	local text = ""
	if name ~= "" and amount and texturePath then
		text = amount.." |T"..texturePath..":12|t"
	end
	return text
end

function private.RepairOnClick(button)
	PlaySound(SOUNDKIT.ITEM_REPAIR)
	button:SetDisabled(true)

	if IsAltKeyDown() then
		if not Vendor.CanGuildRepair() then
			ChatMessage.PrintfUser(L["Cannot repair from the guild bank!"])
			return
		end
		Vendor.DoGuildRepair()
	else
		Vendor.DoRepair()
	end
end
