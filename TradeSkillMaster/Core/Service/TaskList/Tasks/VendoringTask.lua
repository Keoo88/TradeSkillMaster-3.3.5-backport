-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local LibTSMClass = LibStub("LibTSMClass")
local VendoringTask = LibTSMClass.DefineClass("VendoringTask", TSM.TaskList.ItemTask)
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Vendor = TSM.LibTSMService:Include("Vendor")
TSM.TaskList.VendoringTask = VendoringTask
local private = {
	query = nil,
	activeTasks = {},
}



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function VendoringTask.__init(self)
	self.__super:__init()

	if not private.query then
		private.query = Vendor.NewScannerQuery()
			:SetUpdateCallback(private.QueryUpdateCallback)
	end
end

function VendoringTask.Acquire(self, doneHandler, category)
	self.__super:Acquire(doneHandler, category, L["Buy from Vendor"])
	private.activeTasks[self] = true
end

function VendoringTask.Release(self)
	self.__super:Release()
	private.activeTasks[self] = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendoringTask.OnButtonClick(self)
	local itemsToBuy = TempTable.Acquire()
	local query = Vendor.NewScannerQuery()
		:Select("itemString")
	for _, itemString in query:Iterator() do
		itemsToBuy[itemString] = self:GetItems()[itemString]
	end
	query:Release()

	local didBuy = false
	for itemString, quantity in pairs(itemsToBuy) do
		TSM.Vendoring.Buy.BuyItem(itemString, quantity)
		self:_RemoveItem(itemString, quantity)
		didBuy = true
	end
	TempTable.Release(itemsToBuy)

	if didBuy then
		TSM.TaskList.OnTaskUpdated(self)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function VendoringTask._UpdateState(self)
	if not TSM.UI.VendoringUI.IsVisible() then
		return self:_SetButtonState(false, L["NOT OPEN"])
	end
	local canBuy = false
	for itemString in pairs(self:GetItems()) do
		if Vendor.GetFirstIndex(itemString) then
			canBuy = true
			break
		end
	end
	if not canBuy then
		return self:_SetButtonState(false, L["NO ITEMS"])
	else
		return self:_SetButtonState(true, L["BUY"])
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueryUpdateCallback()
	for task in pairs(private.activeTasks) do
		task:Update()
	end
end
