-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local DestroyingUI = TSM.UI:NewPackage("DestroyingUI") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local Conversions = TSM.LibTSMApp:Include("Service.Conversions")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	manager = nil, ---@type UIManager
	settings = nil, ---@type SettingsView
	query = nil, ---@type DatabaseQuery
}
local MIN_FRAME_SIZE = { width = 280, height = 280 }
local CONVERSION_METHODS = {
	Conversion.METHOD.PROSPECT,
	Conversion.METHOD.MILL,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("DESTROYING_UI_STATE")
	:AddOptionalTableField("combineFuture")
	:AddOptionalTableField("destroyFuture")
	:AddOptionalTableField("frame")
	:AddBooleanField("canCombine", false)
	:AddBooleanField("canDestroy", false)
	:AddBooleanField("autoShow", false)
	:AddBooleanField("autoCombine", false)
	:AddBooleanField("didAutoShow", false)
	:AddBooleanField("hasActiveFuture", false)
	:AddBooleanField("canCombineOrDestroy", false)
	:Commit()


-- ============================================================================
-- Module Functions
-- ============================================================================

function DestroyingUI.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "destroyingUIContext", "frame")
		:AddKey("global", "destroyingUIContext", "itemsScrollingTable")
		:AddKey("global", "destroyingOptions", "autoShow")
		:AddKey("global", "destroyingOptions", "autoStack")
end

function DestroyingUI.OnEnable(settingsDB)
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("DESTROYING", state, private.ActionHandler)

	-- Set up some computed state properties
	private.manager:SetStateFromPublisher("hasActiveFuture", state:PublisherForExpression([[combineFuture or destroyFuture]])
		:MapToBoolean()
	)
	private.manager:SetStateFromPublisher("canCombineOrDestroy", state:PublisherForExpression([[canCombine or canDestroy]]))

	-- Setup publisher to set state.canCombine
	private.manager:SetStateFromPublisher("canCombine", TSM.Destroying.CanCombinePublisher())

	-- Create query and setup publisher for state.canDestroy
	private.query = TSM.Destroying.CreateBagQuery()
	private.manager:SetStateFromPublisher("canDestroy", private.query:Publisher()
		:MapToValue(private.query)
		:MapWithMethod("Count")
		:MapBooleanNotEquals(0)
	)

	-- Setup publishers to set state.autoShow/autoCombine from settings
	private.manager:SetStateFromPublisher("autoCombine", private.settings:PublisherForKey("autoStack"))
	private.manager:SetStateFromPublisher("autoShow", private.settings:PublisherForKey("autoShow"))

	-- Publisher for when we have something to combine/destory
	private.manager:ProcessActionFromPublisher("ACTION_CAN_COMBINE_OR_DESTROY", state:PublisherForExpression([[autoShow and not didAutoShow and canCombineOrDestroy]])
		:IgnoreIfNotEquals(true)
	)

	-- Publisher for when we don't have anything to combine/destory
	private.manager:ProcessActionFromPublisher("ACTION_CAN_NOT_COMBINE_OR_DESTROY", state:PublisherForKeyChange("canCombineOrDestroy")
		:IgnoreIfNotEquals(false)
	)
end

function DestroyingUI.OnDisable()
	private.manager:ProcessAction("ACTION_ON_DISABLE")
end

function DestroyingUI.Toggle()
	private.manager:ProcessAction("ACTION_TOGGLE")
end



-- ============================================================================
-- Main Frame
-- ============================================================================

---@param state DestroyingUIState
function private.CreateMainFrame(state)
	return UIElements.New("ApplicationFrame", "base")
		:SetParent(UIParent)
		:SetManager(private.manager)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetStrata("HIGH")
		:SetTitle(L["Destroying"])
		:SetScript("OnHide", private.FrameOnHide)
		:SetContentFrame(UIElements.New("Frame", "content")
			:SetLayout("VERTICAL")
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "item")
				:SetLayout("VERTICAL")
				:SetHeight(82)
				:SetMargin(8)
				:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
				:SetBorderColor("FRAME_BG")
				:AddChild(UIElements.New("Frame", "header")
					:SetLayout("HORIZONTAL")
					:SetPadding(8, 8, 8, 4)
					:SetHeight(32)
					:SetRoundedBackgroundColor("FRAME_BG")
					:AddChild(UIElements.New("Button", "icon")
						:SetSize(20, 20)
						:SetMargin(0, 5, 0, 0)
					)
					:AddChild(UIElements.New("Text", "name")
						:SetHeight(20)
						:SetFont("ITEM_BODY2")
					)
				)
				-- Draw a line along the bottom to hide the rounded corners at the bottom of the header frame
				:AddChildNoLayout(UIElements.New("Texture", "line")
					:AddAnchor("BOTTOMLEFT", "header")
					:AddAnchor("BOTTOMRIGHT", "header")
					:SetHeight(4)
					:SetColor("FRAME_BG")
				)
				:AddChild(UIElements.New("Frame", "container")
					:SetLayout("VERTICAL")
					:SetPadding(0, 0, 4, 4)
					:AddChild(UIElements.New("ScrollFrame", "scroll")
						:SetPadding(8, 8, 0, 0)
					)
				)
			)
			:AddChild(UIElements.New("DestroyingScrollTable", "items")
				:SetSettings(private.settings, "itemsScrollingTable")
				:SetQuery(private.query)
				:SetAction("OnSelectionChanged", "ACTION_ITEM_SELECTION_CHANGED")
				:SetAction("OnHideIconClick", "ACTION_HIDE_ITEM")
			)
			:AddChild(UIElements.New("HorizontalLine", "lineBottom"))
			:AddChildIf(not ClientInfo.IsRetail(), UIElements.New("ActionButton", "combineBtn")
				:SetHeight(26)
				:SetMargin(12, 12, 12, 0)
				:SetTextPublisher(state:PublisherForKeyChange("combineFuture")
					:MapToBoolean()
					:MapBooleanWithValues(L["Combining..."], L["Combine Partial Stacks"])
				)
				:SetDisabledPublisher(state:PublisherForExpression([[hasActiveFuture or not canCombine]]))
				:SetPressedPublisher(state:PublisherForKeyChange("combineFuture"):MapToBoolean())
				:SetAction("OnClick", "ACTION_COMBINE_START")
			)
			:AddChild(UIElements.NewNamed("SecureMacroActionButton", "destroyBtn", "TSMDestroyBtn")
				:SetHeight(26)
				:SetMargin(12, 12, 8, 12)
				:SetTextPublisher(state:PublisherForKeyChange("destroyFuture")
					:MapToBoolean()
					:MapBooleanWithValues(L["Destroying..."], L["Destroy Next"])
				)
				:SetDisabledPublisher(state:PublisherForExpression([[hasActiveFuture or not canDestroy]]))
				:SetPressedPublisher(state:PublisherForKeyChange("destroyFuture"):MapToBoolean())
				:SetAction("PreClick", "ACTION_DESTROY_START")
			)
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state DestroyingUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		assert(not state.frame and state.canCombineOrDestroy)
		UIUtils.AnalyticsRecordPathChange("destroying")
		state.didAutoShow = true
		state.frame = private.CreateMainFrame(state)
		state.frame:Show()
		state.frame:Draw()
		manager:ProcessAction("ACTION_ITEM_SELECTION_CHANGED")
		if state.autoCombine then
			-- We should auto-combine first
			manager:ProcessAction("ACTION_COMBINE_START")
		end
	elseif action == "ACTION_FRAME_ON_HIDE" then
		UIUtils.AnalyticsRecordClose("destroying")
		assert(state.frame)
		if state.combineFuture then
			manager:CancelFuture("combineFuture")
		end
		if state.destroyFuture then
			manager:CancelFuture("destroyFuture")
		end
		state.frame:Hide()
		state.frame:Release()
		state.frame = nil
	elseif action == "ACTION_COMBINE_START" then
		local future = TSM.Destroying.StartCombine()
		-- Don't care about the result of the future
		manager:ManageFuture("combineFuture", future)
	elseif action == "ACTION_DESTROY_START" then
		local future = TSM.Destroying.StartDestroy(state.frame:GetElement("content.destroyBtn"), state.frame:GetElement("content.items"):GetSelection())
		-- Don't care about the result of the future
		manager:ManageFuture("destroyFuture", future)
	elseif action == "ACTION_TOGGLE" then
		if state.frame then
			state.frame:Hide()
		elseif state.canCombineOrDestroy then
			return manager:ProcessAction("ACTION_FRAME_SHOW")
		else
			ChatMessage.PrintUser(L["There is nothing in your inventory to destroy which matches your settings."])
		end
	elseif action == "ACTION_ON_DISABLE" or action == "ACTION_CAN_NOT_COMBINE_OR_DESTROY" then
		if state.frame then
			state.frame:Hide()
		end
	elseif action == "ACTION_CAN_COMBINE_OR_DESTROY" then
		if not state.frame then
			return manager:ProcessAction("ACTION_FRAME_SHOW")
		end
	elseif action == "ACTION_ITEM_SELECTION_CHANGED" then
		local scrollTable = state.frame:GetElement("content.items")
		local itemString = scrollTable:GetSelection()
		if not itemString then
			-- Just select the first row
			return scrollTable:SelectFirstItem()
		end

		local itemFrame = state.frame:GetElement("content.item")
		itemFrame:GetElement("header.icon")
			:SetBackground(ItemInfo.GetTexture(itemString))
			:SetTooltip(itemString)
		itemFrame:GetElement("header.name")
			:SetText(UIUtils.GetDisplayItemName(itemString) or "")

		local info, targetItems = private.GetDestroyInfo(itemString)
		local scrollFrame = itemFrame:GetElement("container.scroll")
		scrollFrame:ReleaseAllChildren()
		for i, text in ipairs(info) do
			scrollFrame:AddChild(UIElements.New("Button", "row"..i)
				:SetHeight(14)
				:SetFont("ITEM_BODY3")
				:SetJustifyH("LEFT")
				:SetText(text)
				:SetTooltip(targetItems[i])
			)
		end
		TempTable.Release(info)
		TempTable.Release(targetItems)
		itemFrame:Draw()
	elseif action == "ACTION_HIDE_ITEM" then
		local itemString, isPermanent = ...
		if isPermanent then
			ChatMessage.PrintfUser(L["Destroying will ignore %s permanently. You can remove it from the ignored list in the settings."], ItemInfo.GetName(itemString))
			TSM.Destroying.IgnoreItemPermanent(itemString)
		else
			ChatMessage.PrintfUser(L["Destroying will ignore %s until you log out."], ItemInfo.GetName(itemString))
			TSM.Destroying.IgnoreItemSession(itemString)
		end
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameOnHide()
	private.manager:ProcessAction("ACTION_FRAME_ON_HIDE")
end

function private.GetDestroyInfo(itemString)
	local classId = ItemInfo.GetClassId(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	local itemLevel = ClientInfo.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBase(itemString))
	local expansion = ClientInfo.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
	local info = TempTable.Acquire()
	local targetItems = TempTable.Acquire()
	for targetItemString in Conversion.DisenchantTargetItemIterator() do
		local amountOfMats, matRate, minAmount, maxAmount = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
		if amountOfMats then
			local name = ItemInfo.GetName(targetItemString)
			local color = ItemInfo.GetQualityColor(targetItemString)
			if name and color then
				matRate = matRate and matRate * 100
				matRate = matRate and matRate.."% " or ""
				local range = (minAmount and maxAmount) and Theme.GetColor("FEEDBACK_YELLOW"):ColorText(minAmount ~= maxAmount and (" ["..minAmount.."-"..maxAmount.."]") or (" ["..minAmount.."]")) or ""
				tinsert(info, color..matRate..name.." x"..amountOfMats.."|r"..range)
				tinsert(targetItems, targetItemString)
			end
		end
	end
	for _, method in ipairs(CONVERSION_METHODS) do
		for targetItemString, amountOfMats, matRate, minAmount, maxAmount in Conversion.TargetItemsByMethodIterator(itemString, method) do
			local name = ItemInfo.GetName(targetItemString)
			local color = ItemInfo.GetQualityColor(targetItemString)
			if name and color then
				matRate = matRate and matRate * 100
				matRate = matRate and matRate.."% " or ""
				local range = (minAmount and maxAmount) and Theme.GetColor("FEEDBACK_YELLOW"):ColorText(minAmount ~= maxAmount and (" ["..minAmount.."-"..maxAmount.."]") or (" ["..minAmount.."]")) or ""
				tinsert(info, color..matRate..name.." x"..amountOfMats.."|r"..range)
				tinsert(targetItems, targetItemString)
			end
		end
	end
	return info, targetItems
end
