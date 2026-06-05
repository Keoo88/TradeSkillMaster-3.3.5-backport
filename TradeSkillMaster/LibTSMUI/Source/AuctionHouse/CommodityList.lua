-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local AuctionHouseUIUtils = LibTSMUI:Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ROW_HEIGHT = 20
local WARNING_TEXTURE = "iconPack.12x12/Attention"



-- ============================================================================
-- Element Definition
-- ============================================================================

local CommodityList = UIElements.Define("CommodityList", "List")
CommodityList:_AddActionScripts("OnRowClick")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CommodityList:__init()
	self.__super:__init()
	self._row = nil
	self._selectedIndex = 0
	self._marketValueFunc = nil
	self._marketThreshold = math.huge
	self._alertThreshold = math.huge
end

function CommodityList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function CommodityList:Release()
	self._row = nil
	self._selectedIndex = 0
	self._marketValueFunc = nil
	self._marketThreshold = math.huge
	self._alertThreshold = math.huge
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the result row.
---@param row AuctionRow The row to set
---@return CommodityList
function CommodityList:SetData(row)
	self._row = row
	self:_SetNumRows(row:GetNumSubRows())
	return self
end

function CommodityList:GetTotalQuantity(maxIndex)
	local totalQuantity = 0
	for i = 1, min(self._row:GetNumSubRows(), maxIndex) do
		local subRow = self._row:GetCommoditySubRow(i)
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local quantityAvailable = subRow:GetQuantities() - numOwnerItems
		totalQuantity = totalQuantity + quantityAvailable
	end
	return totalQuantity
end

---Sets the selected quantity.
---@param quantity number The selected quantity
---@return CommodityList
function CommodityList:SelectQuantity(quantity)
	local maxIndex = nil
	for i = 1, self._row:GetNumSubRows() do
		local subRow = self._row:GetCommoditySubRow(i)
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local quantityAvailable = subRow:GetQuantities() - numOwnerItems
		maxIndex = i
		quantity = quantity - quantityAvailable
		if quantity <= 0 then
			break
		end
	end
	self._selectedIndex = maxIndex and self:_SanitizeSelectionIndex(maxIndex) or 0
	self:_DrawRows()
	return self
end

---Sets the market value function.
---@param func function The function to call with the ResultSubRow to get the market value
---@return CommodityList
function CommodityList:SetMarketValueFunction(func)
	self._marketValueFunc = func
	return self
end

---Sets the alert threshold.
---@param threshold number The item buyout above which the alert icon should be shown
---@return CommodityList
function CommodityList:SetAlertThreshold(threshold)
	self._alertThreshold = threshold
	return self
end

---Sets the market threshold.
---@param threshold number The item buyout above which the alert icon should be shown
---@return CommodityList
function CommodityList:SetMarketThreshold(threshold)
	self._marketThreshold = threshold
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function CommodityList.__protected:_HandleRowAcquired(row)
	-- Warning icon
	local warning = row:AddTexture("warning")
	warning:TSMSetTextureAndSize(WARNING_TEXTURE)
	row:AddTooltipRegion("warningTooltip", warning, self:__closure("_GetWarningBtnTooltip"))

	-- Buyout text
	local buyout = row:AddText("buyout")
	buyout:SetHeight(ROW_HEIGHT)
	buyout:TSMSetFont("TABLE_TABLE1")

	-- Quantity text
	local quantity = row:AddText("quantity")
	quantity:TSMSetSize(60, ROW_HEIGHT)
	quantity:TSMSetFont("TABLE_TABLE1")
	quantity:SetJustifyH("RIGHT")

	-- Percent text
	local percent = row:AddText("percent")
	percent:TSMSetSize(50, ROW_HEIGHT)
	percent:TSMSetFont("TABLE_TABLE1")
	percent:SetJustifyH("RIGHT")

	-- Layout the elements
	local colSpacing = Theme.GetColSpacing()
	warning:SetPoint("LEFT", colSpacing / 2, 0)
	buyout:SetPoint("LEFT", warning, "RIGHT", colSpacing, 0)
	buyout:SetPoint("RIGHT", quantity, "LEFT", -colSpacing, 0)
	quantity:SetPoint("RIGHT", percent, "LEFT", -colSpacing, 0)
	percent:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function CommodityList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local subRow = self._row:GetCommoditySubRow(dataIndex)
	local _, itemBuyout = subRow:GetBuyouts()
	local _, numOwnerItems = subRow:GetOwnerInfo()
	local totalQuantity = subRow:GetQuantities()

	local showWarning = itemBuyout >= self._alertThreshold or itemBuyout >= self._marketThreshold
	row:GetTexture("warning"):SetShown(showWarning)
	row:SetTooltipRegionShown("warningTooltip", showWarning)

	row:GetText("buyout"):SetText(Money.ToStringForAH(itemBuyout))

	local quantityAvailable = totalQuantity - numOwnerItems
	local quantity = row:GetText("quantity")
	quantity:TSMSetTextColor(quantityAvailable == 0 and "INDICATOR_ALT" or "TEXT")
	quantity:SetText(quantityAvailable == 0 and totalQuantity or quantityAvailable)

	local pct = self:_GetMarketValuePct(subRow)
	row:GetText("percent"):SetText(AuctionHouseUIUtils.GetMarketValuePercentText(pct))

	row:SetSelected(self:_IsSelected(dataIndex, subRow))
end

---@param row ListRow
function CommodityList.__protected:_HandleRowClick(row, mouseButton)
	local index = self:_SanitizeSelectionIndex(row:GetDataIndex())
	if not index then
		return
	end
	self._selectedIndex = index
	self:_DrawRows()
	self:_SendActionScript("OnRowClick", index)
end

function CommodityList.__private:_GetWarningBtnTooltip(dataIndex)
	local subRow = self._row:GetCommoditySubRow(dataIndex)
	local _, itemBuyout = subRow:GetBuyouts()
	return itemBuyout >= self._marketThreshold and L["This price is above your material value."] or L["This price is above your confirmation alert threshold."]
end

function CommodityList.__private:_SanitizeSelectionIndex(selectedIndex)
	-- Select the highest subrow which isn't the player's auction and isn't above the selection
	local highestIndex = nil
	for i = 1, self._row:GetNumSubRows() do
		local subRow = self._row:GetCommoditySubRow(i)
		if subRow:GetQuantities() - select(2, subRow:GetOwnerInfo()) ~= 0 then
			highestIndex = i
		end
		if i == selectedIndex then
			break
		end
	end
	return highestIndex
end

function CommodityList.__private:_IsSelected(index, subRow)
	if index > self._selectedIndex then
		return false
	end
	local _, numOwnerItems = subRow:GetOwnerInfo()
	local quantityAvailable = subRow:GetQuantities() - numOwnerItems
	return quantityAvailable > 0
end

function CommodityList.__private:_GetMarketValuePct(row)
	assert(row:IsSubRow())
	if not self._marketValueFunc then
		-- No market value function was set
		return nil, nil
	end
	local marketValue = self._marketValueFunc(row) or 0
	if marketValue == 0 then
		-- This item doesn't have a market value
		return nil, nil
	end
	local _, itemBuyout = row:GetBuyouts()
	return itemBuyout > 0 and Math.Round(100 * itemBuyout / marketValue) or nil
end
