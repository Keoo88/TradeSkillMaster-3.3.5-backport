-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local Send = TSM.UI.MailingUI:NewPackage("Send") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local FSM = TSM.LibTSMUtil:Include("FSM")
local Database = TSM.LibTSMUtil:Include("Database")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local Container = TSM.LibTSMWoW:Include("API.Container")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Inbox = TSM.LibTSMWoW:Include("API.Inbox")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local private = {
	manager = nil, ---@type UIManager
	settings = nil,
	fsm = nil,
	frame = nil,
	db = nil,
	query = nil,
	recipient = "",
	subject = "",
	body = "",
	money = 0,
	isMoney = true,
	isCOD = false,
	mailShowingTimer = nil,
	queryCancellable = nil,
}
local PLAYER_NAME = UnitName("player")
local PLAYER_NAME_REALM = gsub(PLAYER_NAME.."-"..GetRealmName(), "%s+", "")
local MAX_COD_AMOUNT = 10000 * COPPER_PER_GOLD
local STATE_SCHEMA = Reactive.CreateStateSchema("MAILING_SEND_UI_STATE")
	:AddOptionalTableField("frame")
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Send.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "mailingOptions", "recentlyMailedList")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_SEND", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_NAME_INPUT_CHANGED")

	private.mailShowingTimer = DelayTimer.New("MAILING_SEND_MAIL_SHOWING", function() SetSendMailShowing(true) end)
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(L["Send"], private.GetSendFrame)

	private.db = Database.NewSchema("MAILTRACKING_SEND_INFO")
		:AddStringField("itemString")
		:AddNumberField("quantity")
		:Commit()
	private.query = private.db:NewQuery()
end

function Send.SetSendRecipient(recipient)
	private.recipient = recipient
end



-- ============================================================================
-- Send UI
-- ============================================================================

function private.GetSendFrame()
	UIUtils.AnalyticsRecordPathChange("mailing", "send")
	assert(not private.queryCancellable)
	private.queryCancellable = private.query:Publisher()
		:CallFunction(private.SendOnDataUpdated)
		:Stored()
	local frame = UIElements.New("Frame", "send")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:AddChild(UIElements.New("Frame", "container")
			:SetLayout("VERTICAL")
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Text", "recipient")
				:SetMargin(8, 8, 8, 8)
				:SetHeight(24)
				:SetFont("BODY_BODY1_BOLD")
				:SetText(L["Recipient"])
			)
			:AddChild(UIElements.New("Frame", "name")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 8)
				:AddChild(UIElements.New("Input", "input")
					:SetHintText(L["Enter recipient name"])
					:SetAutoComplete(PlayerInfo.GetConnectedAlts())
					:SetClearButtonEnabled(true)
					:SetValue(private.recipient)
					:SetAction("OnValueChanged", "ACTION_HANDLE_NAME_INPUT_CHANGED")
				)
				:AddChild(UIElements.New("ActionButton", "contacts")
					:SetWidth(152)
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Contacts"])
					:SetAction("OnClick", "ACTION_SHOW_CONTACTS_DIALOG")
				)
			)
			:AddChild(UIElements.New("Frame", "subject")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 16)
				:AddChild(UIElements.New("Button", "icon")
					:SetMargin(4, 4, 0, 0)
					:SetBackgroundAndSize("iconPack.12x12/Add/Circle")
					:SetScript("OnClick", private.SubjectBtnOnClick)
				)
				:AddChild(UIElements.New("Button", "text")
					:SetWidth("AUTO")
					:SetText(L["Add subject & description (optional)"])
					:SetFont("BODY_BODY2")
					:SetScript("OnClick", private.SubjectBtnOnClick)
				)
				:AddChild(UIElements.New("Button", "button")
					:SetWidth("AUTO")
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_BODY2")
					:SetTextColor("INDICATOR")
					:SetText(L["Edit"])
					:SetScript("OnClick", private.SubjectBtnOnClick)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 4)
				:AddChild(UIElements.New("Text", "items")
					:SetFont("BODY_BODY1_BOLD")
					:SetText(L["Select Items to Attach"])
				)
			)
			:AddChild(UIElements.New("Frame", "dragBox")
				:SetLayout("VERTICAL")
				:SetBackgroundColor("PRIMARY_BG")
				:RegisterForDrag("LeftButton")
				:SetScript("OnReceiveDrag", private.DragBoxOnItemRecieve)
				:SetScript("OnMouseUp", private.DragBoxOnItemRecieve)
				:AddChild(UIElements.New("SendItemsList", "items")
					:SetQuery(private.query)
					:SetScript("OnRemoveItem", private.ListOnRemoveItem)
				)
				:AddChild(UIElements.New("HorizontalLine", "line"))
				:AddChild(UIElements.New("Frame", "footer")
					:SetLayout("HORIZONTAL")
					:SetHeight(26)
					:SetPadding(8, 8, 3, 3)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "items")
						:SetWidth(144)
						:SetFont("BODY_BODY2_MEDIUM")
						:SetJustifyH("RIGHT")
						:Hide()
					)
					:AddChild(UIElements.New("Texture", "vline")
						:SetWidth(1)
						:SetMargin(8, 8, 3, 3)
						:SetColor("ACTIVE_BG_ALT")
						:Hide()
					)
					:AddChild(UIElements.New("Text", "postage")
						:SetWidth(150)
						:SetFont("BODY_BODY2_MEDIUM")
						:SetJustifyH("RIGHT")
						:SetText(L["Total Postage"]..": "..Money.ToStringExact(30))
					)
				)
			)
			:AddChild(UIElements.New("HorizontalLine", "line"))
			:AddChild(UIElements.New("Frame", "check")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(8, 0, 8, 6)
				:AddChild(UIElements.New("Checkbox", "sendCheck")
					:SetWidth("AUTO")
					:SetMargin(0, 0, 1, 0)
					:SetFont("BODY_BODY2")
					:SetChecked(private.isMoney)
					:SetText(L["Send Money"])
					:SetScript("OnValueChanged", private.SendOnValueChanged)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "checkbox")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 8)
				:AddChild(UIElements.New("Checkbox", "cod")
					:SetSize("AUTO", 20)
					:SetFont("BODY_BODY2")
					:SetChecked(private.isCOD)
					:SetText(L["Make Cash On Delivery?"])
					:SetDisabled(true)
					:SetScript("OnValueChanged", private.CODOnValueChanged)
				)
				:AddChild(UIElements.New("Text", "amountText")
					:SetHeight(20)
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetJustifyH("RIGHT")
					:SetText(L["Amount"]..":")
				)
				:AddChild(UIElements.New("Input", "moneyInput")
					:SetWidth(160)
					:SetBackgroundColor("ACTIVE_BG")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetValidateFunc(private.MoneyValidateFunc)
					:SetJustifyH("RIGHT")
					:SetValue(Money.ToStringExact(private.money))
					:SetScript("OnValueChanged", private.MoneyOnValueChanged)
				)
			)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "sendMail")
				:SetHeight(24)
				:SetText(L["Send Mail"])
				:SetScript("OnClick", private.SendMail)
				:SetDisabled(private.recipient == "")
			)
			:AddChild(UIElements.New("Button", "clear")
				:SetWidth("AUTO")
				:SetHeight(24)
				:SetMargin(16, 10, 0, 0)
				:SetFont("BODY_BODY3_MEDIUM")
				:SetJustifyH("LEFT")
				:SetText(L["Clear All"])
				:SetScript("OnClick", private.ClearOnClick)
			)
		)
		:SetScript("OnUpdate", private.SendFrameOnUpdate)
		:SetScript("OnHide", private.SendFrameOnHide)
		:SetScript("OnShow", private.SendFrameOnShow)

	private.frameWasShown = false
	private.manager:ProcessAction("ACTION_HANDLE_FRAME_SHOWN", frame)
	private.frame = frame

	return frame
end

function private.SubjectBtnOnClick(button)
	button:GetBaseElement():ShowDialogFrame(UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(478, 314)
		:SetPadding(12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, -4, 14)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY1_BOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Add Subject / Description"])
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.CloseDialog)
			)
		)
		:AddChild(UIElements.New("Text", "subjectText")
			:SetMargin(0, 0, 0, 4)
			:SetHeight(20)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Subject"])
		)
		:AddChild(UIElements.New("Input", "subjectInput")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetMaxLetters(64)
			:SetClearButtonEnabled(true)
			:SetValue(private.subject)
			:SetTabPaths("__parent.descriptionInput", "__parent.descriptionInput")
			:SetScript("OnValueChanged", private.SubjectOnValueChanged)
		)
		:AddChild(UIElements.New("Text", "descriptionText")
			:SetHeight(20)
			:SetMargin(0, 0, 0, 4)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(DESCRIPTION or "Description")
		)
		:AddChild(UIElements.New("MultiLineInput", "descriptionInput")
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetIgnoreEnter()
			:SetMaxLetters(500)
			:SetValue(private.body)
			:SetTabPaths("__parent.subjectInput", "__parent.subjectInput")
			:SetScript("OnValueChanged", private.DesciptionOnValueChanged)
		)
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 0, 4, 12)
			:AddChild(UIElements.New("Text", "title")
				:SetHeight(20)
				:SetMargin(0, 4, 0, 0)
				:SetFont("BODY_BODY3")
				:SetJustifyH("RIGHT")
				:SetText(format(L["(%d/500 Characters)"], #private.body))
			)
			:AddChild(UIElements.New("Button", "clearAll")
				:SetSize("AUTO", 20)
				:SetFont("BODY_BODY3_MEDIUM")
				:SetJustifyH("LEFT")
				:SetText(L["Clear All"])
				:SetDisabled(private.subject == "" and private.body == "")
				:SetScript("OnClick", private.SubjectClearAllBtnOnClick)
			)
		)
		:AddChild(UIElements.New("ActionButton", "addMailBtn")
			:SetHeight(24)
			:SetText(L["Add to Mail"])
			:SetScript("OnClick", private.CloseDialog)
			:SetDisabled(private.subject == "" and private.body == "")
		)
		:SetScript("OnHide", private.DialogOnHide)
	)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.SendFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame)
end

function private.SendFrameOnHide(frame)
	if frame ~= private.frame then return end
	-- 3.3.5: WoW Frame создаётся hidden по умолчанию, SetScript("OnHide") ловит
	-- этот initial hide-state и срабатывает сразу. Игнорируем пока frame ещё
	-- ни разу не было реально показано.
	if not private.frameWasShown then
		if TSMDBG then TSMDBG.Log("Send", "OnHide ignored: initial spurious hide") end
		return
	end
	private.frame = nil
	private.frameWasShown = false
	if private.queryCancellable then
		private.queryCancellable:Cancel()
		private.queryCancellable = nil
	end

	private.manager:ProcessAction("ACTION_HANDLE_FRAME_HIDDEN")
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end

function private.SendFrameOnShow(frame)
	private.frameWasShown = true
	if TSMDBG then TSMDBG.Log("Send", "OnShow real: frame now visible") end
end

function private.ClearOnClick(button)
	private.fsm:ProcessEvent("EV_MAIL_CLEAR", true)
end

function private.CloseDialog(button)
	button:GetBaseElement():HideDialog()

	private.fsm:ProcessEvent("EV_DIALOG_HIDDEN")
end

function private.DialogOnHide(button)
	private.fsm:ProcessEvent("EV_DIALOG_HIDDEN")
end

function private.DragBoxOnItemRecieve(frame, button)
	if not CursorHasItem() then
		ClearCursor()
		return
	end

	if private.query:Count() >= 12 then
		ClearCursor()
		UIErrorsFrame:AddMessage(ERR_MAIL_INVALID_ATTACHMENT_SLOT, 1.0, 0.1, 0.1, 1.0)
		return
	end

	local _, _, subType = GetCursorInfo()
	local itemString = ItemString.Get(subType)
	local stackSize = nil
	-- 3.3.5: the slotDB "isBound" flag is unreliable here (it ends up true for many
	-- perfectly mailable items, including account-bound ones), so filtering on it
	-- dropped account-bound items from drag-and-drop: stackSize stayed nil and nothing
	-- was added to the send list (regular unbound items still worked). Mirror
	-- BagTracking.GetNumMailable / CreateQueryBagsAuctionable and only apply the
	-- isBound filter on clients that actually report it; account-bound items are
	-- mailable to your own characters.
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("bag", "slot", "quantity")
		:Equal("itemString", itemString)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		query:Equal("isBound", false)
	end
	for _, bag, slot, quantity in query:Iterator() do
		if Container.IsBagSlotLocked(bag, slot) then
			stackSize = quantity
		end
	end
	query:Release()
	ClearCursor()
	if not stackSize then
		return
	end

	private.DatabaseNewRow(itemString, stackSize)
end

function private.ListOnRemoveItem(_, row)
	private.db:DeleteRow(row)
end

function private.SendOnDataUpdated()
	private.fsm:ProcessEvent("EV_MAIL_DATA_UPDATED")
end

function private.SubjectClearAllBtnOnClick(button)
	private.subject = ""
	private.body = ""

	button:GetElement("__parent.__parent.subjectInput")
		:SetFocused(false)
		:SetValue(private.subject)
		:Draw()
	button:GetElement("__parent.__parent.descriptionInput")
		:SetFocused(false)
		:SetValue(private.body)
		:Draw()
	button:GetElement("__parent.title")
		:SetText(format(L["(%d/500 Characters)"], 0))
		:Draw()
	button:SetDisabled(true)
		:Draw()
	button:GetElement("__parent.__parent.addMailBtn")
		:SetDisabled(true)
		:Draw()
end

function private.SubjectOnValueChanged(input)
	local value = input:GetValue()
	if value == private.subject then
		return
	end
	private.subject = value
	input:GetElement("__parent.footer.clearAll")
		:SetDisabled(private.subject == "" and private.body == "")
		:Draw()
	input:GetElement("__parent.addMailBtn")
		:SetDisabled(private.subject == "" and private.body == "")
		:Draw()
end

function private.DesciptionOnValueChanged(input)
	local text = input:GetValue()
	if text == private.body then
		return
	end
	private.body = text
	input:GetElement("__parent.footer.title")
		:SetText(format(L["(%d/500 Characters)"], #private.body))
		:Draw()
	input:GetElement("__parent.footer.clearAll")
		:SetDisabled(private.subject == "" and private.body == "")
		:Draw()
	input:GetElement("__parent.addMailBtn")
		:SetDisabled(private.subject == "" and private.body == "")
		:Draw()
end

function private.SendOnValueChanged(checkbox)
	if checkbox:IsChecked() then
		checkbox:GetElement("__parent.__parent.checkbox.cod"):SetChecked(false)
			:Draw()

		private.isMoney = true
		private.isCOD = false
	else
		private.isMoney = false
	end
end

function private.CODOnValueChanged(checkbox)
	if checkbox:IsChecked() then
		checkbox:GetElement("__parent.__parent.check.sendCheck"):SetChecked(false)
			:Draw()

		local input = checkbox:GetElement("__parent.moneyInput")
		local value = private.ConvertMoneyValue(input:GetValue())
		private.money = private.isCOD and min(value, MAX_COD_AMOUNT) or value
		input:SetValue(Money.ToStringExact(private.money))
			:Draw()

		private.isMoney = false
		private.isCOD = true
	else
		private.isCOD = false
	end
end

function private.ConvertMoneyValue(value)
	value = gsub(value, String.Escape(LARGE_NUMBER_SEPERATOR), "")
	value = tonumber(value) or Money.FromString(value)
	if not value then
		return nil
	end
	local maxVal = private.isCOD and MAX_COD_AMOUNT or MAXIMUM_BID_PRICE
	return value >= 0 and value <= maxVal and value or nil
end

function private.MoneyValidateFunc(_, value)
	return private.ConvertMoneyValue(value) and true or false
end

function private.MoneyOnValueChanged(input)
	local value = private.ConvertMoneyValue(input:GetValue())
	assert(value)
	if value == private.money then
		return
	end
	private.money = value
	input:SetValue(Money.ToStringExact(value))
		:Draw()
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state MailingSendUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_FRAME_SHOWN" then
		local frame = ...
		assert(frame)
		state.frame = frame
		if TSMDBG then TSMDBG.Log("Send", "FRAME_SHOWN frame=%s state=%s", tostring(frame), tostring(state)) end
	elseif action == "ACTION_HANDLE_FRAME_HIDDEN" then
		if TSMDBG then TSMDBG.Log("Send", "FRAME_HIDDEN was=%s state=%s", tostring(state.frame), tostring(state)) end
		state.frame = nil
	elseif action == "ACTION_HANDLE_NAME_INPUT_CHANGED" then
		if TSMDBG then TSMDBG.Log("Send", "NAME_INPUT_CHANGED stateFrame=%s privateFrame=%s",
			tostring(state.frame ~= nil), tostring(private.frame ~= nil)) end
		if not state.frame then return end
		local value = state.frame:GetElement("container.name.input"):GetValue() or ""
		if TSMDBG then TSMDBG.Log("Send", "  value='%s' prevRecipient='%s'", tostring(value), tostring(private.recipient)) end
		if value == private.recipient then
			return
		end
		private.recipient = value
		private.UpdateSendFrame()
	elseif action == "ACTION_SHOW_CONTACTS_DIALOG" then
		if not state.frame then return end
		state.frame:GetElement("container.name.input")
			:SetFocused(false)
			:Draw()
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("MailContactsDialog", "dialog")
			:AddAnchor("TOP", state.frame:GetElement("container.name.contacts"), "BOTTOM", 0, -6)
			:Configure(private.settings.regionWide)
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_CONTACT_SELECTED")
		)
	elseif action == "ACTION_CONTACT_SELECTED" then
		local character = ...
		state.frame:GetElement("container.name.input")
			:SetValue(character)
			:Draw()
		manager:ProcessAction("ACTION_HANDLE_NAME_INPUT_CHANGED")
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SendMail(button)
	local money = 0
	if private.money > 0 and private.isMoney then
		money = private.money
	elseif private.money > 0 and private.isCOD then
		money = private.money * -1
	end

	-- 3.3.5: SetFocused(false) на input может триггерить OnEditFocusLost и
	-- через цепочку коллбэков перетереть private.recipient. Сохраняем перед.
	local capturedRecipient = private.recipient
	local capturedSubject = private.subject
	local capturedBody = private.body
	button:GetElement("__parent.__parent.container.name.input"):SetFocused(false)
	private.UpdateRecentlyMailed(capturedRecipient)

	-- 3.3.5: IsShiftKeyDown() возвращает nil когда не зажат → array hole в varargs FSM
	local keepInfo = IsShiftKeyDown() and true or false

	if private.query:Count() > 0 then
		local items = {}
		for _, row in private.query:Iterator() do
			local itemString = row:GetField("itemString")
			local quantity = row:GetField("quantity")
			if items[itemString] then
				items[itemString] = items[itemString] + quantity
			else
				items[itemString] = quantity
			end
		end
		private.fsm:ProcessEvent("EV_BUTTON_CLICKED", keepInfo, capturedRecipient, capturedSubject, capturedBody, money, items)
	else
		private.fsm:ProcessEvent("EV_BUTTON_CLICKED", keepInfo, capturedRecipient, capturedSubject, capturedBody, money)
	end
end

function private.UpdateRecentlyMailed(recipient)
	if recipient == UnitName("player") or recipient == PLAYER_NAME_REALM or recipient == "" then
		return
	end

	local size = 0
	local oldestName = nil
	local oldestTime = nil
	for k, v in pairs(private.settings.recentlyMailedList) do
		size = size + 1
		if not oldestName or not oldestTime or oldestTime > v then
			oldestName = k
			oldestTime = v
		end
	end

	if size >= 20 then
		private.settings.recentlyMailedList[oldestName] = nil
	end

	private.settings.recentlyMailedList[recipient] = time()
end

function private.UpdateSendFrame()
	if not private.frame then
		return
	end

	local sendMail = private.frame:GetElement("footer.sendMail")
	if private.recipient and private.recipient ~= "" then
		sendMail:SetDisabled(false)
	else
		sendMail:SetDisabled(true)
	end
	sendMail:Draw()
end

function private.DatabaseNewRow(itemString, stackSize)
	private.db:NewRow()
		:SetField("itemString", itemString)
		:SetField("quantity", stackSize)
		:Create()
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.FSMCreate()
	DefaultUI.RegisterMailVisibleCallback(function() private.fsm:ProcessEvent("EV_MAIL_CLEAR") end, false)
	Event.Register("MAIL_SEND_INFO_UPDATE", function()
		private.fsm:ProcessEvent("EV_MAIL_INFO_UPDATE")
	end)
	Event.Register("MAIL_FAILED", function()
		private.fsm:ProcessEvent("EV_SENDING_DONE")
	end)

	local fsmContext = {
		frame = nil,
		sending = false,
		keepInfo = false
	}

	local function UpdateFrame(context)
		if not context.frame then
			return
		end
		if not context.frame:HasChildById("container") then
			return
		end

		local subject = context.frame:GetElement("container.subject")
		if private.subject == "" and private.body == "" then
			subject:GetElement("icon")
				:SetBackgroundAndSize("iconPack.12x12/Add/Circle")
				:Draw()
			subject:GetElement("text")
				:SetText(L["Add subject & description (optional)"])
				:Draw()
			subject:GetElement("button")
				:Hide()
		else
			subject:GetElement("icon")
				:SetBackgroundAndSize("iconPack.12x12/Checkmark/Default")
				:Draw()
			subject:GetElement("text")
				:SetText(L["Subject & Description added"])
				:Draw()
			subject:GetElement("button")
				:Show()
		end
		subject:Draw()

		local items = context.frame:GetElement("container.dragBox.footer.items")
		local line = context.frame:GetElement("container.dragBox.footer.vline")
		local postage = context.frame:GetElement("container.dragBox.footer.postage")
		local send = context.frame:GetElement("container.check.sendCheck")
		local cod = context.frame:GetElement("container.checkbox.cod")

		local size = private.query:Count()
		if size > 0 then
			postage:SetText(L["Total Postage"]..": "..Money.ToStringExact(30 * size))
				:Draw()
			items:SetText(format(L["%s Items Selected"], Theme.GetColor("FEEDBACK_GREEN"):ColorText(size.."/"..Inbox.GetMaxSendAttachments())))
				:Show()
				:Draw()
			line:Show()
			cod:SetDisabled(false)
				:Draw()
		else
			postage:SetText(L["Total Postage"]..": "..Money.ToStringExact(30))
				:Draw()
			items:Hide()
			line:Hide()
			cod:SetDisabled(true)
				:Draw()
			send:SetChecked(true)
				:SetDisabled(false)
				:Draw()
		end
	end

	local function UpdateButton(context)
		context.frame:GetElement("footer.sendMail")
			:SetText(context.sending and L["Sending..."] or L["Send Mail"])
			:SetPressed(context.sending)
			:Draw()
	end

	local function UpdateSendMailInfo(context)
		if private.query:Count() >= 12 then
			UIErrorsFrame:AddMessage(ERR_MAIL_INVALID_ATTACHMENT_SLOT, 1.0, 0.1, 0.1, 1.0)
		else
			for i = 1, Inbox.GetMaxSendAttachments() do
				-- 3.3.5: GetSendMailItem(i) → (name, texture, count, quality, charges) — count это 3-й параметр
				local itemName, _, stackCount = GetSendMailItem(i)
				if itemName and stackCount and stackCount > 0 then
					local itemLink = GetSendMailItemLink(i)
					local itemString = ItemString.Get(itemLink)

					private.DatabaseNewRow(itemString, stackCount)

					break
				end
			end
		end

		ClearSendMail()
	end

	local function ClearMail(context, keepInfo, redraw)
		if not keepInfo then
			private.recipient = ""
		end
		private.subject = ""
		private.body = ""
		private.money = 0
		private.isMoney = true
		private.isCOD = false

		private.db:Truncate()

		if redraw and context.frame then
			context.frame:GetElement("container.name.input")
				:SetValue(private.recipient)
				:Draw()
			context.frame:GetElement("container.checkbox.moneyInput")
				:SetValue(Money.ToStringExact(private.money))
				:Draw()
			if not keepInfo then
				context.frame:GetElement("footer.sendMail")
					:SetDisabled(true)
					:Draw()
			end
		end

		UpdateFrame(context)
	end

	private.fsm = FSM.New("MAILING_SEND")
		:AddState(FSM.NewState("ST_HIDDEN")
			:SetOnEnter(function(context)
				TSM.Mailing.Send.KillThread()
				SetSendMailShowing(false)
				context.frame = nil
				private.db:Truncate()
			end)
			:AddTransition("ST_SHOWN")
			:AddTransition("ST_HIDDEN")
			:AddEventTransition("EV_FRAME_SHOW", "ST_SHOWN")
		)
		:AddState(FSM.NewState("ST_SHOWN")
			:SetOnEnter(function(context, frame)
				if not context.frame then
					context.frame = frame
					UpdateFrame(context)
					private.mailShowingTimer:RunForFrames(2)
				end
				UpdateButton(context)
			end)
			:AddTransition("ST_HIDDEN")
			:AddTransition("ST_SENDING_START")
			:AddEvent("EV_DIALOG_HIDDEN", function(context)
				UpdateFrame(context)
			end)
			:AddEvent("EV_MAIL_INFO_UPDATE", function(context)
				UpdateSendMailInfo(context)
				UpdateFrame(context)
			end)
			:AddEvent("EV_MAIL_DATA_UPDATED", function(context)
				UpdateFrame(context)
			end)
			:AddEvent("EV_MAIL_CLEAR", function(context, redraw)
				ClearMail(context, IsShiftKeyDown(), redraw)
			end)
			:AddEvent("EV_BUTTON_CLICKED", function(context, keepInfo, recipient, subject, body, money, items)
				-- 3.3.5: IsShiftKeyDown() возвращает nil когда не зажат → array hole в FSM transition
				-- Конвертируем в boolean чтобы избежать nil в varargs
				keepInfo = keepInfo and true or false

				context.sending = true
				context.keepInfo = keepInfo
				private.db:SetQueryUpdatesPaused(true)
				TSM.Mailing.Send.StartSending(private.FSMSendCallback, recipient, subject, body, money, items)
				UpdateButton(context)
				-- FSM требует вернуть state + все параметры для SetOnEnter
				return "ST_SENDING_START", keepInfo, recipient, subject, body, money, items
			end)
		)
		:AddState(FSM.NewState("ST_SENDING_START")
			:SetOnEnter(function(context, keepInfo, recipient, subject, body, money, items)
				-- StartSending уже вызван из EV_BUTTON_CLICKED handler, здесь ничего не делаем
				-- Параметры передаются для сохранения в context если понадобится в будущем
			end)
			:SetOnExit(function(context)
				context.sending = false
				private.db:SetQueryUpdatesPaused(false)
				ClearMail(context, context.keepInfo, true)
				UpdateFrame(context)
			end)
			:AddTransition("ST_SHOWN")
			:AddTransition("ST_HIDDEN")
			:AddEventTransition("EV_SENDING_DONE", "ST_SHOWN")
		)
		:AddDefaultEvent("EV_FRAME_HIDE", function(context)
			context.frame = nil
			return "ST_HIDDEN"
		end)
		:Init("ST_HIDDEN", fsmContext)
end

function private.FSMSendCallback()
	private.fsm:ProcessEvent("EV_SENDING_DONE")
end
