-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local BankingUI = TSM.UI:NewPackage("BankingUI") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local FSM = TSM.LibTSMUtil:Include("FSM")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	fsm = nil,
	groupSearch = "",
}
local MIN_FRAME_SIZE = { width = 325, height = 600 }
local MODULE_LIST = {
	"Warehousing",
	"Auctioning",
	"Mailing",
}
local BUTTON_TEXT_LOOKUP = {
	Warehousing = L["Warehousing"],
	Auctioning = L["Auctioning"],
	Mailing = L["Mailing"],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function BankingUI.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "bankingUIContext", "frame")
		:AddKey("global", "bankingUIContext", "isOpen")
		:AddKey("global", "bankingUIContext", "tab")
		:AddKey("char", "bankingUIContext", "warehousingGroupTree")
		:AddKey("char", "bankingUIContext", "auctioningGroupTree")
		:AddKey("char", "bankingUIContext", "mailingGroupTree")
	private.FSMCreate()
end

function BankingUI.OnDisable()
	-- Hide the frame
	private.fsm:ProcessEvent("EV_BANK_CLOSED")
end

function BankingUI.Toggle()
	private.fsm:ProcessEvent("EV_TOGGLE")
end



-- ============================================================================
-- Main Frame
-- ============================================================================

function private.CreateMainFrame()
	UIUtils.AnalyticsRecordPathChange("banking")
	local frame = UIElements.New("ApplicationFrame", "base")
		:SetParent(UIParent)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetStrata("HIGH")
		:SetTitle(L["Banking"])
		:SetScript("OnHide", private.BaseFrameOnHide)
		:SetContentFrame(UIElements.New("Frame", "content")
			:SetLayout("VERTICAL")
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Frame", "navButtons")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(8)
				:SetPadding(-4, 0, 0, 0) -- Account for the left margin of the first button
			)
			:AddChild(UIElements.New("Frame", "search")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 12)
				:AddChild(UIElements.New("Input", "input")
					:SetIconTexture("iconPack.18x18/Search")
					:AllowItemInsert(true)
					:SetClearButtonEnabled(true)
					:SetValue(private.groupSearch)
					:SetHintText(L["Search Groups"])
					:SetScript("OnValueChanged", private.GroupSearchOnValueChanged)
				)
				:AddChild(UIElements.New("Button", "expandAllBtn")
					:SetSize(24, 24)
					:SetMargin(8, 4, 0, 0)
					:SetBackground("iconPack.18x18/Expand All")
					:SetScript("OnClick", private.ExpandAllGroupsOnClick)
					:SetTooltip(L["Expand / Collapse All Groups"])
				)
				:AddChild(UIElements.New("Button", "selectAllBtn")
					:SetSize(24, 24)
					:SetBackground("iconPack.18x18/Select All")
					:SetScript("OnClick", private.SelectAllGroupsOnClick)
					:SetTooltip(L["Select / Deselect All Groups"])
				)
			)
			:AddChild(UIElements.New("ApplicationGroupTree", "groupTree")
				:SetSettingsContext(private.settings, private.GetSettingsContextKey())
				:SetQuery(GroupOperation.CreateQuery(), private.settings.tab)
				:SetSearchString(private.groupSearch)
			)
			:AddChild(UIElements.New("HorizontalLine", "line"))
			:AddChild(UIElements.New("Frame", "footer")
				:SetLayout("VERTICAL")
				:SetHeight(ClientInfo.IsRetail() and 202 or 170)
				:SetPadding(8)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("ProgressBar", "progressBar")
					:SetHeight(24)
					:SetProgress(0)
					:SetProgressIconHidden(true)
					:SetText(L["Select Action"])
				)
				:AddChild(UIElements.New("Frame", "buttons")
					:SetLayout("VERTICAL")
				)
			)
		)
	frame:GetElement("titleFrame.closeBtn"):SetScript("OnClick", private.CloseBtnOnClick)

	for _, module in ipairs(MODULE_LIST) do
		frame:GetElement("content.navButtons"):AddChild(UIElements.New("ActionButton", "navBtn_"..module)
			:SetHeight(20)
			:SetMargin(4, 0, 0, 0)
			:SetFont("BODY_BODY3_MEDIUM")
			:SetContext(module)
			:SetText(BUTTON_TEXT_LOOKUP[module])
			:SetScript("OnClick", private.NavBtnOnClick)
		)
	end

	private.UpdateCurrentModule(frame)

	return frame
end

function private.GetSettingsContextKey()
	if private.settings.tab == "Warehousing" then
		return "warehousingGroupTree"
	elseif private.settings.tab == "Auctioning" then
		return "auctioningGroupTree"
	elseif private.settings.tab == "Mailing" then
		return "mailingGroupTree"
	else
		error("Unexpected tab: "..tostring(private.settings.tab))
	end
end

function private.UpdateCurrentModule(frame)
	-- Update navigation buttons
	local navButtonsFrame = frame:GetElement("content.navButtons")
	for _, module in ipairs(MODULE_LIST) do
		navButtonsFrame:GetElement("navBtn_"..module)
			:SetPressed(module == private.settings.tab)
	end
	navButtonsFrame:Draw()

	-- Update group tree
	frame:GetElement("content.groupTree")
		:SetSettingsContext(private.settings, private.GetSettingsContextKey())
		:SetQuery(GroupOperation.CreateQuery(), private.settings.tab)
		:Draw()

	-- Update footer buttons
	local footerButtonsFrame = frame:GetElement("content.footer.buttons")
	footerButtonsFrame:ReleaseAllChildren()
	if private.settings.tab == "Warehousing" then
		footerButtonsFrame:AddChild(UIElements.New("Frame", "row1")
			:SetLayout("HORIZONTAL")
			:AddChild(UIElements.New("ActionButton", "moveBankBtn")
				:SetHeight(24)
				:SetMargin(0, 8, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Move to bank"])
				:SetContext(TSM.Banking.Warehousing.MoveGroupsToBank)
				:SetScript("OnClick", private.GroupBtnOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "moveBagsBtn")
				:SetHeight(24)
				:SetMargin(0, 0, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Move to bags"])
				:SetContext(TSM.Banking.Warehousing.MoveGroupsToBags)
				:SetScript("OnClick", private.GroupBtnOnClick)
			)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "restockBagsBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Restock bags"])
			:SetContext(TSM.Banking.Warehousing.RestockBags)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "depositReagentsBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetDisabled(not ClientInfo.IsRetail())
			:SetText(L["Deposit reagents"])
			:SetScript("OnClick", private.WarehousingDepositReagentsBtnOnClick)
		)
		footerButtonsFrame:AddChildIf(ClientInfo.IsRetail(), UIElements.New("ActionButton", "depositWarboundBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Deposit Warbound items"])
			:SetScript("OnClick", private.WarehousingDepositWarboundBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("Frame", "row4")
			:SetLayout("HORIZONTAL")
			:AddChild(UIElements.New("ActionButton", "emptyBagsBtn")
				:SetHeight(24)
				:SetMargin(0, 8, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Empty bags"])
				:SetContext(TSM.Banking.EmptyBags)
				:SetScript("OnClick", private.SimpleBtnOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "restoreBagsBtn")
				:SetHeight(24)
				:SetMargin(0, 0, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Restore bags"])
				:SetContext(TSM.Banking.RestoreBags)
				:SetScript("OnClick", private.SimpleBtnOnClick)
			)
		)
	elseif private.settings.tab == "Auctioning" then
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "moveBankBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Move to bank"])
			:SetContext(TSM.Banking.Auctioning.MoveGroupsToBank)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "postCapBagsBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Post cap to bags"])
			:SetContext(TSM.Banking.Auctioning.PostCapToBags)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "shortfallBagsBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Shortfall to bags"])
			:SetContext(TSM.Banking.Auctioning.ShortfallToBags)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "maxExpBankBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Max expires to bank"])
			:SetContext(TSM.Banking.Auctioning.MaxExpiresToBank)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
	elseif private.settings.tab == "Mailing" then
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "moveBankBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Move to bank"])
			:SetContext(TSM.Banking.Mailing.MoveGroupsToBank)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "nongroupBankBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Nongroup to bank"])
			:SetContext(TSM.Banking.Mailing.NongroupToBank)
			:SetScript("OnClick", private.SimpleBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("ActionButton", "targetShortfallBagsBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Target shortfall to bags"])
			:SetContext(TSM.Banking.Mailing.TargetShortfallToBags)
			:SetScript("OnClick", private.GroupBtnOnClick)
		)
		footerButtonsFrame:AddChild(UIElements.New("Frame", "row4")
			:SetLayout("HORIZONTAL")
			:AddChild(UIElements.New("ActionButton", "emptyBagsBtn")
				:SetHeight(24)
				:SetMargin(0, 8, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Empty bags"])
				:SetContext(TSM.Banking.EmptyBags)
				:SetScript("OnClick", private.SimpleBtnOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "restoreBagsBtn")
				:SetHeight(24)
				:SetMargin(0, 0, 8, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Restore bags"])
				:SetContext(TSM.Banking.RestoreBags)
				:SetScript("OnClick", private.SimpleBtnOnClick)
			)
		)
	else
		error("Unexpected module: "..tostring(private.settings.tab))
	end
	footerButtonsFrame:Draw()
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.BaseFrameOnHide()
	UIUtils.AnalyticsRecordClose("banking")
end

function private.CloseBtnOnClick(button)
	ChatMessage.PrintUser(L["Hiding the TSM Banking UI. Type '/tsm bankui' to reopen it."])
	button:GetParentElement():Hide()
	private.fsm:ProcessEvent("EV_FRAME_HIDDEN")
end

function private.GroupSearchOnValueChanged(input)
	private.groupSearch = strlower(input:GetValue())
	input:GetElement("__parent.__parent.groupTree")
		:SetSearchString(private.groupSearch)
		:Draw()
end

function private.NavBtnOnClick(button)
	private.settings.tab = button:GetContext()
	private.UpdateCurrentModule(button:GetBaseElement())
	private.fsm:ProcessEvent("EV_NAV_CHANGED")
end

function private.ExpandAllGroupsOnClick(button)
	button:GetElement("__parent.__parent.groupTree")
		:ToggleExpandAll()
end

function private.SelectAllGroupsOnClick(button)
	button:GetElement("__parent.__parent.groupTree")
		:ToggleSelectAll()
end

function private.WarehousingDepositReagentsBtnOnClick()
	if ClientInfo.IsRetail() then
		C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Character)
	else
		DepositReagentBank()
	end
end

function private.WarehousingDepositWarboundBtnOnClick()
	if C_Bank and C_Bank.AutoDepositItemsIntoBank and Enum.BankType then
		C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)
	end
end

function private.SimpleBtnOnClick(button)
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", button, button:GetContext())
end

function private.GroupBtnOnClick(button)
	local groups = TempTable.Acquire()
	for _, groupPath in button:GetElement("__base.content.groupTree"):SelectedGroupsIterator() do
		groups[groupPath] = true
	end
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", button, button:GetContext(), groups)
	TempTable.Release(groups)
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.FSMCreate()
	local fsmContext = {
		frame = nil,
		isWarBank = false,
		progress = nil,
		activeButton = nil,
	}

	TSM.Banking.RegisterFrameCallback(function(openFrame)
		private.fsm:ProcessEvent(openFrame and "EV_BANK_OPENED" or "EV_BANK_CLOSED")
		local warBankOpen = TSM.Banking.IsWarBankOpen()
		if fsmContext.isWarBank ~= warBankOpen then
			private.fsm:ProcessEvent("EV_BANK_TYPE_UPDATED", warBankOpen)
		end
	end)

	local function UpdateFrame(context)
		if context.activeButton and not context.progress then
			context.activeButton
				:SetPressed(false)
				:Draw()
			context.activeButton = nil
		end

		-- Update the navigation button state
		local navButtonsFrame = context.frame:GetElement("content.navButtons")
		for _, module in ipairs(MODULE_LIST) do
			navButtonsFrame:GetElement("navBtn_"..module)
				:SetDisabled(context.progress)
		end
		navButtonsFrame:Draw()

		-- Update the progress bar
		context.frame:GetElement("content.footer.progressBar")
			:SetProgress(context.progress or 0)
			:SetProgressIconHidden(not context.progress)
			:SetText(context.progress and L["Moving"] or L["Select Action"])
			:Draw()

		-- Update the action button state
		context.frame:SetTitle(context.isWarBank and L["Warbank"] or BANK)
		local footerButtonsFrame = context.frame:GetElement("content.footer.buttons")
		if private.settings.tab == "Warehousing" then
			footerButtonsFrame:GetElement("row1.moveBankBtn")
				:SetDisabled(context.progress)
				:SetText(context.isWarBank and L["Move to warbank"] or L["Move to bank"])
			footerButtonsFrame:GetElement("row1.moveBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("restockBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("depositReagentsBtn")
				:SetDisabled(context.progress or not ClientInfo.IsRetail())
			footerButtonsFrame:GetElement("row4.emptyBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("row4.restoreBagsBtn")
				:SetDisabled(context.progress or not TSM.Banking.CanRestoreBags())
		elseif private.settings.tab == "Auctioning" then
			footerButtonsFrame:GetElement("moveBankBtn")
				:SetDisabled(context.progress)
				:SetText(context.isWarBank and L["Move to warbank"] or L["Move to bank"])
			footerButtonsFrame:GetElement("postCapBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("shortfallBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("maxExpBankBtn")
				:SetDisabled(context.progress)
		elseif private.settings.tab == "Mailing" then
			footerButtonsFrame:GetElement("moveBankBtn")
				:SetDisabled(context.progress)
				:SetText(context.isWarBank and L["Move to warbank"] or L["Move to bank"])
			footerButtonsFrame:GetElement("nongroupBankBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("targetShortfallBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("row4.emptyBagsBtn")
				:SetDisabled(context.progress)
			footerButtonsFrame:GetElement("row4.restoreBagsBtn")
				:SetDisabled(context.progress or not TSM.Banking.CanRestoreBags())
		else
			error("Unexpected module: "..tostring(private.settings.tab))
		end
		footerButtonsFrame:Draw()
	end
	private.fsm = FSM.New("BANKING_UI")
		:AddState(FSM.NewState("ST_CLOSED")
			:SetOnEnter(function(context)
				if context.frame then
					context.frame:Hide()
					context.frame:Release()
					context.frame = nil
					context.isWarBank = false
				end
				context.activeButton = nil
			end)
			:AddTransition("ST_CLOSED")
			:AddTransition("ST_FRAME_OPEN")
			:AddTransition("ST_FRAME_HIDDEN")
			:AddEvent("EV_BANK_OPENED", function(context)
				assert(not context.frame)
				if not private.settings.isOpen then
					return "ST_FRAME_HIDDEN"
				end
				return "ST_FRAME_OPEN"
			end)
		)
		:AddState(FSM.NewState("ST_FRAME_HIDDEN")
			:SetOnEnter(function(context)
				private.settings.isOpen = false
				if context.frame then
					context.frame:Hide()
					context.frame:Release()
					context.frame = nil
					context.isWarBank = false
				end
				context.activeButton = nil
			end)
			:AddTransition("ST_FRAME_OPEN")
			:AddTransition("ST_CLOSED")
			:AddEvent("EV_TOGGLE", function()
				private.settings.isOpen = true
				return "ST_FRAME_OPEN"
			end)
		)
		:AddState(FSM.NewState("ST_FRAME_OPEN")
			:SetOnEnter(function(context)
				if not context.frame then
					context.frame = private.CreateMainFrame()
					context.frame:Show()
					context.frame:Draw()
				end
				UpdateFrame(context)
			end)
			:AddTransition("ST_FRAME_OPEN")
			:AddTransition("ST_FRAME_HIDDEN")
			:AddTransition("ST_PROCESSING")
			:AddTransition("ST_CLOSED")
			:AddEvent("EV_BANK_TYPE_UPDATED", function(context, isWarBank)
				context.isWarBank = isWarBank
				UpdateFrame(context)
			end)
			:AddEventTransition("EV_BUTTON_CLICKED", "ST_PROCESSING")
			:AddEventTransition("EV_TOGGLE", "ST_FRAME_HIDDEN")
			:AddEventTransition("EV_FRAME_HIDDEN", "ST_FRAME_HIDDEN")
			:AddEventTransition("EV_NAV_CHANGED", "ST_FRAME_OPEN")
		)
		:AddState(FSM.NewState("ST_PROCESSING")
			:SetOnEnter(function(context, button, startFunc, ...)
				context.activeButton = button
				context.activeButton
					:SetPressed(true)
					:Draw()
				context.progress = 0
				startFunc(private.FSMThreadCallback, ...)
				UpdateFrame(context)
			end)
			:SetOnExit(function(context)
				context.progress = nil
			end)
			:AddTransition("ST_FRAME_OPEN")
			:AddTransition("ST_FRAME_HIDDEN")
			:AddTransition("ST_CLOSED")
			:AddEvent("EV_THREAD_PROGRESS", function(context, progress)
				context.progress = progress
				UpdateFrame(context)
			end)
			:AddEvent("EV_THREAD_DONE", function(context)
				if context.progress == 0 then
					ChatMessage.PrintUser(L["Nothing to move."])
				end
				return "ST_FRAME_OPEN"
			end)
			:AddEventTransition("EV_TOGGLE", "ST_FRAME_HIDDEN")
		)
		:AddDefaultEventTransition("EV_BANK_CLOSED", "ST_CLOSED")
		:Init("ST_CLOSED", fsmContext)
end

function private.FSMThreadCallback(event, ...)
	if event == "PROGRESS" then
		private.fsm:ProcessEvent("EV_THREAD_PROGRESS", ...)
	elseif event == "DONE" then
		private.fsm:ProcessEvent("EV_THREAD_DONE")
	elseif event == "MOVED" then
		-- Ignore this event
	else
		error("Unexpected event: "..tostring(event))
	end
end
