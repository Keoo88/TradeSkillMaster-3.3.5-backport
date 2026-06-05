-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local General = TSM.MainUI.Settings:NewPackage("General") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Sync = TSM.LibTSMService:Include("Sync")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ChatFrame = TSM.LibTSMWoW:Include("API.ChatFrame")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local Tooltip = TSM.LibTSMUI:Include("Tooltip")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local StaticPopupDialog = TSM.LibTSMWoW:IncludeClassType("StaticPopupDialog")
local AppHelper = TSM.LibTSMApp:Include("Service.AppHelper")
local private = {
	settingsDB = nil,
	settings = nil,
	frame = nil,
	characterList = {},
	characterKeys = {},
	guildList = {},
	chatFrameList = {},
	destroySources = {},
	destroySourceKeys = {},
	altRealmSources = {},
	altRealmSourceKeys = {},
}
local INVALID_DESTROY_PRICE_SOURCES = {
	crafting = true,
	vendorbuy = true,
	vendorsell = true,
	destroy = true,
	itemquality = true,
	itemlevel = true,
	requiredlevel = true,
	numinventory = true,
	numexpires = true,
	salerate = true,
	dbregionsalerate = true,
	dbregionsoldperday = true,
	auctioningopmin = true,
	auctioningopmax = true,
	auctioningopnormal = true,
	shoppingopmax = true,
	sniperopmax = true,
}
local CHARACTER_SEP = "\001"
local SETTING_TOOLTIPS = {
	regionWide = L["If enabled, TSM will load data (i.e. inventory / Accounting / gold tracking) from every realm you have characters on, instead of just connected realms."],
	globalOperations = L["If this option is enabled any operation created will be stored by TSM without any association to a specific profile that is loaded at the time of creation. This means operations will be available to all profiles. Note: Storing operations globally will also mean no operations are included when sending a profile to a synced account."],
	groupPriceSource = L["This field defines the value to filter items in groups. Note: This field is not related to Shopping, Browsing, or Sniping the Auction House."],
	chatFrame = L["Select the chat tab to show TSM addon related messages."],
	forgetCharacter = L["Selecting any character in this drop down list will instruct TSM to forget everything known about it including professions, inventory, and current gold."],
	ignoreGuilds = L["Selecting any guild in this drop down will instruct TSM to disregard the contents of the guild bank for inventory tracking purposes."],
	destroyValueSource = L["Select from any available price source in this drop down list to change the way TSM values the results of destroying an item (i.e disenchanting, prospecting, or milling)."],
	auctionDBAltRealm = L["Loads AuctionDB data for an additional realm for display in the tooltip."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function General.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "coreOptions", "globalOperations")
		:AddKey("global", "coreOptions", "protectAuctionHouse")
		:AddKey("global", "coreOptions", "chatFrame")
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:AddKey("factionrealm", "coreOptions", "ignoreGuilds")
		:AddKey("factionrealm", "internalData", "pendingMail")
		:AddKey("factionrealm", "internalData", "characterGuilds")
		:AddKey("realm", "coreOptions", "auctionDBAltRealm")
	TSM.MainUI.Settings.RegisterSettingPage(L["General Settings"], "top", private.GetGeneralSettingsFrame)
	Sync.RegisterConnectionChangedCallback(private.SyncConnectionChangedCallback)
end



-- ============================================================================
-- General Settings UI
-- ============================================================================

function private.GetGeneralSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "general")
	wipe(private.chatFrameList)
	local defaultChatFrame = nil
	for i = 1, NUM_CHAT_WINDOWS do
		local name = strlower(GetChatWindowInfo(i) or "")
		if DEFAULT_CHAT_FRAME == _G["ChatFrame"..i] then
			defaultChatFrame = name
		end
		if name ~= "" and _G["ChatFrame"..i.."Tab"]:IsVisible() and not tContains(private.chatFrameList, name) then
			tinsert(private.chatFrameList, name)
		end
	end
	if not tContains(private.chatFrameList, private.settings.chatFrame) then
		if tContains(private.chatFrameList, defaultChatFrame) then
			private.settings.chatFrame = defaultChatFrame
			ChatFrame.SetActive(defaultChatFrame)
		else
			-- All chat frames are hidden, so just disable the setting
			wipe(private.chatFrameList)
		end
	end

	wipe(private.characterList)
	wipe(private.characterKeys)
	for _, character, factionrealm in PlayerInfo.CharacterIterator(true) do
		if not SessionInfo.IsPlayer(character, factionrealm) then
			tinsert(private.characterKeys, character..CHARACTER_SEP..factionrealm)
			tinsert(private.characterList, SessionInfo.FormatCharacterName(character, factionrealm))
		end
	end

	wipe(private.guildList)
	for _, guild in PlayerInfo.GuildIterator(true) do
		tinsert(private.guildList, guild)
	end

	wipe(private.destroySources)
	wipe(private.destroySourceKeys)
	local foundCurrentSetting = false
	for _, key, label in CustomString.SourceIterator() do
		key = strlower(key)
		if not INVALID_DESTROY_PRICE_SOURCES[key] then
			tinsert(private.destroySources, label)
			tinsert(private.destroySourceKeys, key)
			if private.settings.destroyValueSource == key then
				foundCurrentSetting = true
			end
		end
	end
	if not foundCurrentSetting then
		-- The current setting isn't in the list, so reset it to the default
		private.settings.destroyValueSource = strlower(private.settings:GetDefaultReadOnly("destroyValueSource"))
	end

	wipe(private.altRealmSources)
	wipe(private.altRealmSourceKeys)
	tinsert(private.altRealmSources, L["None"])
	tinsert(private.altRealmSourceKeys, "")
	for altRealm in AppHelper.AltRealmIterator() do
		tinsert(private.altRealmSources, altRealm)
		tinsert(private.altRealmSourceKeys, altRealm)
	end

	return UIElements.New("ScrollFrame", "generalSettings")
		:SetPadding(8, 8, 8, 0)
		:SetScript("OnUpdate", private.FrameOnUpdate)
		:SetScript("OnHide", private.FrameOnHide)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("General", "general", L["General Options"], L["Some general TSM options are below."])
			:AddChildIf(ClientInfo.HasFeature(ClientInfo.FEATURES.REGION_WIDE_TRADING), UIElements.New("Frame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "regionWide")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Enable region-wide trading (requires reload)"])
					:SetSettingInfo(private.settings, "regionWide")
					:SetScript("OnValueChanged", private.RegionWideOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.regionWide, "__parent")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "globalOperations")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Share operations between all profiles"])
					:SetChecked(private.settings.globalOperations)
					:SetScript("OnValueChanged", private.GlobalOperationsOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.globalOperations, "__parent")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChildIf(not ClientInfo.IsRetail(), UIElements.New("Frame", "check3")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "protectAuctionHouse")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Prevent closing the Auction House with the esc key"])
					:SetSettingInfo(private.settings, "protectAuctionHouse")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("generalGroupPriceField", L["Filter group item lists based on the following price source"], private.settings, "groupPriceSource", nil, nil, SETTING_TOOLTIPS.groupPriceSource))
			:AddChild(UIElements.New("Frame", "dropdownLabelLine")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 12, 4)
				:AddChild(UIElements.New("Text", "chatTabLabel")
					:SetMargin(0, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Chat Tab"])
				)
				:AddChild(UIElements.New("Text", "forgetLabel")
					:SetMargin(0, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Forget Character"])
				)
				:AddChild(UIElements.New("Text", "ignoreLabel")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Ignore Guilds"])
				)
			)
			:AddChild(UIElements.New("Frame", "dropdownLine")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("SelectionDropdown", "chatTabDropdown")
					:SetMargin(0, 16, 0, 0)
					:SetItems(private.chatFrameList, private.chatFrameList)
					:SetSettingInfo(next(private.chatFrameList) and private.settings or nil, "chatFrame")
					:SetScript("OnSelectionChanged", private.ChatTabOnSelectionChanged)
					:SetTooltip(SETTING_TOOLTIPS.chatFrame, "__parent")
				)
				:AddChild(UIElements.New("SelectionDropdown", "forgetDropdown")
					:SetMargin(0, 16, 0, 0)
					:SetItems(private.characterList, private.characterKeys)
					:SetScript("OnSelectionChanged", private.ForgetCharacterOnSelectionChanged)
					:SetTooltip(SETTING_TOOLTIPS.forgetCharacter, "__parent")
				)
				:AddChild(UIElements.New("MultiselectionDropdown", "ignoreDropdown")
					:SetItems(private.guildList, private.guildList)
					:SetSettingInfo(private.settings, "ignoreGuilds")
					:SetSelectionText(L["No Guilds"], L["%d Guilds"], L["All Guilds"])
					:SetTooltip(SETTING_TOOLTIPS.ignoreGuilds, "__parent")
				)
			)
			:AddChild(UIElements.New("Frame", "dropdownLabelLine2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 12, 4)
				:AddChild(UIElements.New("Text", "destroyLabel")
					:SetMargin(0, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Destroy value source"])
				)
				:AddChildIf(ClientInfo.IsRetail(), UIElements.New("Text", "altRealmLabel")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["AuctionDB data alternate realm"])
				)
				:AddChildIf(not ClientInfo.IsRetail(), UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "dropdownLine2")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("SelectionDropdown", "destroyDropdown")
					:SetMargin(0, 16, 0, 0)
					:SetItems(private.destroySources, private.destroySourceKeys)
					:SetSettingInfo(private.settings, "destroyValueSource")
					:SetTooltip(SETTING_TOOLTIPS.destroyValueSource, "__parent")
				)
				:AddChildIf(ClientInfo.IsRetail(), UIElements.New("SelectionDropdown", "altRealmDropdown")
					:SetItems(private.altRealmSources, private.altRealmSourceKeys)
					:SetSettingInfo(private.settings, "auctionDBAltRealm")
					:SetTooltip(SETTING_TOOLTIPS.auctionDBAltRealm, "__parent")
					:SetScript("OnSelectionChanged", private.AltRealmOnSelectionChanged)
				)
				:AddChildIf(not ClientInfo.IsRetail(), UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("General", "profiles", L["Profiles"], L["Set your active profile or create a new one."])
			:AddChildrenWithFunction(private.AddProfileRows)
			:AddChild(UIElements.New("Text", "profileLabel")
				:SetHeight(20)
				:SetMargin(0, 0, 4, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Create new profile"])
			)
			:AddChild(UIElements.New("Input", "newProfileInput")
				:SetHeight(24)
				:SetBackgroundColor("ACTIVE_BG")
				:SetHintText(L["Enter profile name"])
				:SetMaxLetters(64)
				:SetScript("OnEnterPressed", private.NewProfileInputOnEnterPressed)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("General", "accountSync", L["Account Syncing"], L["TSM can automatically sync data between multiple WoW accounts."])
			:AddChildrenWithFunction(private.AddAccountSyncRows)
			:AddChild(UIElements.New("Text", "profileLabel")
				:SetHeight(20)
				:SetMargin(0, 0, 4, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Add account"])
			)
			:AddChild(UIElements.New("Input", "newProfileInput")
				:SetHeight(24)
				:SetBackgroundColor("ACTIVE_BG")
				:SetHintText(L["Enter name of logged-in character on other account"])
				:SetScript("OnEnterPressed", private.NewAccountSyncInputOnEnterPressed)
			)
		)
end

function private.AddProfileRows(frame)
	for index, profileName in private.settingsDB:ScopeKeyIterator("profile") do
		local isCurrentProfile = profileName == private.settingsDB:GetCurrentProfile()
		local row = UIElements.New("Frame", "profileRow_"..index)
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 0, 8)
			:SetPadding(8, 8, 4, 4)
			:SetRoundedBackgroundColor(isCurrentProfile and "ACTIVE_BG" or "PRIMARY_BG_ALT")
			:SetContext(profileName)
			:SetScript("OnEnter", private.ProfileRowOnEnter)
			:SetScript("OnLeave", private.ProfileRowOnLeave)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetText(profileName)
					:SetFont("BODY_BODY2")
					:SetChecked(isCurrentProfile)
					:SetScript("OnValueChanged", private.ProfileCheckboxOnValueChanged)
					:PropagateScript("OnEnter")
					:PropagateScript("OnLeave")
				)
				:PropagateScript("OnEnter")
				:PropagateScript("OnLeave")
			)
			:AddChild(UIElements.New("Button", "resetBtn")
				:SetBackgroundAndSize("iconPack.18x18/Reset")
				:SetMargin(4, 0, 0, 0)
				:SetScript("OnClick", private.ResetProfileOnClick)
				:SetScript("OnEnter", private.ResetProfileOnEnter)
				:SetScript("OnLeave", private.ResetProfileOnLeave)
			)
			:AddChild(UIElements.New("Button", "renameBtn")
				:SetBackgroundAndSize("iconPack.18x18/Edit")
				:SetMargin(4, 0, 0, 0)
				:SetScript("OnClick", private.RenameProfileOnClick)
				:SetScript("OnEnter", private.RenameProfileOnEnter)
				:SetScript("OnLeave", private.RenameProfileOnLeave)
			)
			:AddChild(UIElements.New("Button", "duplicateBtn")
				:SetBackgroundAndSize("iconPack.18x18/Duplicate")
				:SetMargin(4, 0, 0, 0)
				:SetScript("OnClick", private.DuplicateProfileOnClick)
				:SetScript("OnEnter", private.DuplicateProfileOnEnter)
				:SetScript("OnLeave", private.DuplicateProfileOnLeave)
			)
			:AddChild(UIElements.New("Button", "deleteBtn")
				:SetBackgroundAndSize("iconPack.18x18/Delete")
				:SetMargin(4, 0, 0, 0)
				:SetScript("OnClick", private.DeleteProfileOnClick)
				:SetScript("OnEnter", private.DeleteProfileOnEnter)
				:SetScript("OnLeave", private.DeleteProfileOnLeave)
			)
		row:GetElement("deleteBtn"):Hide()
		if not isCurrentProfile then
			row:GetElement("resetBtn"):Hide()
			row:GetElement("renameBtn"):Hide()
			row:GetElement("duplicateBtn"):Hide()
		end
		frame:AddChild(row)
	end
end

function private.AddAccountSyncRows(frame)
	local connectingCharacter = Sync.GetConnectingCharacter()
	if connectingCharacter then
		local row = private.CreateAccountSyncRow("new", format(L["Connecting to %s"], connectingCharacter))
		row:GetElement("sendProfileBtn"):Hide()
		row:GetElement("removeBtn"):Hide()
		frame:AddChild(row)
	end

	for _, account in private.settingsDB:SyncAccountIterator() do
		local characters = TempTable.Acquire()
		for _, character in private.settingsDB:AccessibleCharacterIterator(account) do
			tinsert(characters, character)
		end
		sort(characters)
		local isConnected, connectedCharacter = Sync.GetConnectionStatus(account)
		local statusText = nil
		if isConnected then
			statusText = Theme.GetColor("FEEDBACK_GREEN"):ColorText(format(L["Connected to %s"], connectedCharacter))
		else
			statusText = Theme.GetColor("FEEDBACK_RED"):ColorText(L["Offline"])
		end
		statusText = statusText.." | "..table.concat(characters, ", ")
		TempTable.Release(characters)

		local row = private.CreateAccountSyncRow("accountSyncRow_"..account, statusText)
		row:SetContext(account)
		row:GetElement("sendProfileBtn"):Hide()
		row:GetElement("removeBtn"):Hide()
		frame:AddChild(row)
	end
end

function private.CreateAccountSyncRow(id, statusText)
	local row = UIElements.New("Frame", id)
		:SetLayout("HORIZONTAL")
		:SetHeight(28)
		:SetMargin(0, 0, 0, 8)
		:SetPadding(8, 8, 4, 4)
		:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
		:SetScript("OnEnter", private.AccountSyncRowOnEnter)
		:SetScript("OnLeave", private.AccountSyncRowOnLeave)
		:AddChild(UIElements.New("Text", "status")
			:SetFont("BODY_BODY2")
			:SetText(statusText)
			:SetScript("OnEnter", private.AccountSyncTextOnEnter)
			:SetScript("OnLeave", private.AccountSyncTextOnLeave)
		)
		:AddChild(UIElements.New("Button", "sendProfileBtn")
			:SetBackgroundAndSize("iconPack.18x18/Operation")
			:SetMargin(4, 0, 0, 0)
			:SetScript("OnClick", private.SendProfileOnClick)
			:SetScript("OnEnter", private.SendProfileOnEnter)
			:SetScript("OnLeave", private.SendProfileOnLeave)
		)
		:AddChild(UIElements.New("Button", "removeBtn")
			:SetBackgroundAndSize("iconPack.18x18/Delete")
			:SetMargin(4, 0, 0, 0)
			:SetScript("OnClick", private.RemoveAccountSyncOnClick)
			:SetScript("OnEnter", private.RemoveAccountOnEnter)
			:SetScript("OnLeave", private.RemoveAccountOnLeave)
		)
	return row
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.SyncConnectionChangedCallback()
	if private.frame then
		private.frame:GetParentElement():ReloadContent()
	end
end

function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.frame = frame
end

function private.FrameOnHide(frame)
	private.frame = nil
end

function private.RegionWideOnValueChanged()
	ReloadUI()
end

function private.GlobalOperationsOnValueChanged(checkbox, value)
	-- restore the previous value until it's confirmed
	checkbox:SetChecked(not value, true)
	local desc = L["If you have multiple profiles set up with operations, enabling this will cause all but the current profile's operations to be irreversibly lost."]
	checkbox:GetBaseElement():ShowConfirmationDialog(L["Make Operations Global?"], desc, private.GlobalOperationsConfirmed, checkbox, value)
end

function private.GlobalOperationsConfirmed(checkbox, newValue)
	checkbox:SetChecked(newValue, true)
		:Draw()
	TSM.Operations.SetStoredGlobally(newValue)
end

function private.ChatTabOnSelectionChanged(dropdown)
	ChatFrame.SetActive(dropdown:GetSelectedItem())
end

function private.ForgetCharacterOnSelectionChanged(self)
	local key = self:GetSelectedItemKey()
	if not key then
		return
	end
	local character, factionrealm = strsplit(CHARACTER_SEP, key)
	private.settingsDB:RemoveSyncCharacter(character, factionrealm)
	local pendingMail = private.settings:GetForScopeKey("pendingMail", factionrealm)
	if pendingMail then
		pendingMail[character] = nil
	end
	local characterGuilds = private.settings:GetForScopeKey("characterGuilds", factionrealm)
	if characterGuilds then
		characterGuilds[character] = nil
	end
	ChatMessage.PrintfUser(L["%s removed."], SessionInfo.FormatCharacterName(character, factionrealm))
	local index = Table.KeyByValue(private.characterKeys, key)
	assert(index)
	tremove(private.characterList, index)
	tremove(private.characterKeys, index)
	self:SetSelectedItem(nil)
		:SetItems(private.characterList, private.characterKeys)
		:Draw()
end

function private.AltRealmOnSelectionChanged()
	StaticPopupDialog.ShowWithOk(L["The alt realm selection will not take affect until you next log into the game or reload your UI."])
end

function private.ProfileRowOnEnter(frame)
	local isCurrentProfile = frame:GetContext() == private.settingsDB:GetCurrentProfile()
	frame:SetRoundedBackgroundColor("ACTIVE_BG")
	if not isCurrentProfile then
		frame:GetElement("resetBtn"):Show()
		frame:GetElement("renameBtn"):Show()
		frame:GetElement("duplicateBtn"):Show()
		frame:GetElement("deleteBtn"):Show()
	end
	frame:Draw()
end

function private.ProfileRowOnLeave(frame)
	local isCurrentProfile = frame:GetContext() == private.settingsDB:GetCurrentProfile()
	frame:SetRoundedBackgroundColor(isCurrentProfile and "ACTIVE_BG" or "PRIMARY_BG_ALT")
	if not isCurrentProfile then
		frame:GetElement("resetBtn"):Hide()
		frame:GetElement("renameBtn"):Hide()
		frame:GetElement("duplicateBtn"):Hide()
		frame:GetElement("deleteBtn"):Hide()
	end
	frame:Draw()
end

function private.ProfileCheckboxOnValueChanged(checkbox, value)
	if not value then
		-- can't uncheck profile checkboxes
		checkbox:SetChecked(true, true)
		checkbox:Draw()
		return
	end
	-- uncheck the current profile row
	local currentProfileIndex = nil
	for index, profileName in private.settingsDB:ScopeKeyIterator("profile") do
		if profileName == private.settingsDB:GetCurrentProfile() then
			assert(not currentProfileIndex)
			currentProfileIndex = index
		end
	end
	local prevRow = checkbox:GetElement("__parent.__parent.__parent.profileRow_"..currentProfileIndex)
	prevRow:GetElement("content.checkbox")
		:SetChecked(false, true)
	prevRow:GetElement("resetBtn"):Hide()
	prevRow:GetElement("renameBtn"):Hide()
	prevRow:GetElement("duplicateBtn"):Hide()
	prevRow:GetElement("deleteBtn"):Hide()
	prevRow:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
	prevRow:Draw()
	-- set the profile
	private.settingsDB:SetProfile(checkbox:GetText())
	-- set this row as the current one
	local newRow = checkbox:GetElement("__parent.__parent")
	newRow:SetRoundedBackgroundColor("ACTIVE_BG")
	newRow:GetElement("resetBtn"):Show()
	newRow:GetElement("renameBtn"):Show()
	newRow:GetElement("duplicateBtn"):Show()
	newRow:GetElement("deleteBtn"):Hide()
	newRow:Draw()
end

function private.RenameProfileOnClick(button)
	local profileName = button:GetParentElement():GetContext()
	local dialogFrame = UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(600, 187)
		:AddAnchor("CENTER")
		:SetBackgroundColor("FRAME_BG")
		:SetBorderColor("ACTIVE_BG")
		:AddChild(UIElements.New("Text", "title")
			:SetHeight(44)
			:SetMargin(16, 16, 24, 16)
			:SetFont("BODY_BODY2_BOLD")
			:SetJustifyH("CENTER")
			:SetText(L["Rename Profile"])
		)
		:AddChild(UIElements.New("Input", "nameInput")
			:SetHeight(26)
			:SetMargin(16, 16, 0, 25)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetContext(profileName)
			:SetValue(profileName)
			:SetScript("OnEnterPressed", private.RenameProfileInputOnEnterPressed)
		)
		:AddChild(UIElements.New("Frame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetMargin(16, 16, 0, 16)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("ActionButton", "closeBtn")
				:SetSize(126, 26)
				:SetText(CLOSE)
				:SetScript("OnClick", private.DialogCloseBtnOnClick)
			)
		)
	button:GetBaseElement():ShowDialogFrame(dialogFrame)
	dialogFrame:GetElement("nameInput"):SetFocused(true)
end

function private.DialogCloseBtnOnClick(button)
	private.RenameProfileInputOnEnterPressed(button:GetElement("__parent.__parent.nameInput"))
end

function private.RenameProfileInputOnEnterPressed(input)
	local profileName = input:GetValue()
	local prevProfileName = input:GetContext()
	if profileName == prevProfileName then
		-- just hide the dialog
		local baseElement = input:GetBaseElement()
		baseElement:HideDialog()
		baseElement:GetElement("content.settings.contentFrame.content"):ReloadContent()
		return
	elseif not private.settingsDB:IsValidProfileName(profileName) then
		ChatMessage.PrintUser(L["This is not a valid profile name. Profile names must be at least one character long and may not contain '@' characters."])
		return
	elseif private.settingsDB:ProfileExists(profileName) then
		ChatMessage.PrintUser(L["A profile with this name already exists."])
		return
	end

	-- create a new profile, copy over the settings, then delete the old one
	local currentProfileName = private.settingsDB:GetCurrentProfile()
	private.settingsDB:SetProfile(profileName)
	private.settingsDB:CopyProfile(prevProfileName)
	private.settingsDB:DeleteProfile(prevProfileName, profileName)
	if currentProfileName ~= prevProfileName then
		private.settingsDB:SetProfile(currentProfileName)
	end

	-- hide the dialog and refresh the settings content
	local baseElement = input:GetBaseElement()
	baseElement:HideDialog()
	baseElement:GetElement("content.settings.contentFrame.content"):ReloadContent()
end

function private.RenameProfileOnEnter(button)
	button:ShowTooltip(L["Rename the profile"])
	private.ProfileRowOnEnter(button:GetParentElement())
end

function private.RenameProfileOnLeave(button)
	Tooltip.Hide()
	private.ProfileRowOnLeave(button:GetParentElement())
end

function private.DuplicateProfileOnClick(button)
	local profileName = button:GetParentElement():GetContext()
	local newName = profileName
	while private.settingsDB:ProfileExists(newName) do
		newName = newName.." Copy"
	end
	local activeProfile = private.settingsDB:GetCurrentProfile()
	private.settingsDB:SetProfile(newName)
	private.settingsDB:CopyProfile(profileName)
	private.settingsDB:SetProfile(activeProfile)
	button:GetBaseElement():GetElement("content.settings.contentFrame.content"):ReloadContent()
end

function private.DuplicateProfileOnEnter(button)
	button:ShowTooltip(L["Duplicate the profile"])
	private.ProfileRowOnEnter(button:GetParentElement())
end

function private.DuplicateProfileOnLeave(button)
	Tooltip.Hide()
	private.ProfileRowOnLeave(button:GetParentElement())
end

function private.ResetProfileOnClick(button)
	local profileName = button:GetParentElement():GetContext()
	local desc = format(L["This will reset all groups and operations (if not stored globally) to be wiped from '%s'."], profileName)
	button:GetBaseElement():ShowConfirmationDialog(L["Reset Profile?"], desc, private.ResetProfileConfirmed, profileName)
end

function private.ResetProfileConfirmed(profileName)
	local activeProfile = private.settingsDB:GetCurrentProfile()
	private.settingsDB:SetProfile(profileName)
	private.settingsDB:ResetProfile()
	private.settingsDB:SetProfile(activeProfile)
end

function private.ResetProfileOnEnter(button)
	button:ShowTooltip(L["Reset the current profile to default settings"])
	private.ProfileRowOnEnter(button:GetParentElement())
end

function private.ResetProfileOnLeave(button)
	Tooltip.Hide()
	private.ProfileRowOnLeave(button:GetParentElement())
end

function private.DeleteProfileOnClick(button)
	local profileName = button:GetParentElement():GetContext()
	local desc = format(L["This will permanently delete the '%s' profile."], profileName)
	button:GetBaseElement():ShowConfirmationDialog(L["Delete Profile?"], desc, private.DeleteProfileConfirmed, button, profileName)
end

function private.DeleteProfileConfirmed(button, profileName)
	local newProfileName = nil
	for _, otherProfileName in private.settingsDB:ScopeKeyIterator("profile") do
		if not newProfileName and otherProfileName ~= profileName then
			newProfileName = otherProfileName
		end
	end
	assert(newProfileName)
	private.settingsDB:DeleteProfile(profileName, newProfileName)
	button:GetBaseElement():GetElement("content.settings.contentFrame.content"):ReloadContent()
end

function private.DeleteProfileOnEnter(button)
	button:ShowTooltip(L["Delete the profile"])
	private.ProfileRowOnEnter(button:GetParentElement())
end

function private.DeleteProfileOnLeave(button)
	Tooltip.Hide()
	private.ProfileRowOnLeave(button:GetParentElement())
end

function private.NewProfileInputOnEnterPressed(input)
	local profileName = input:GetValue()
	if not private.settingsDB:IsValidProfileName(profileName) then
		ChatMessage.PrintUser(L["This is not a valid profile name. Profile names must be at least one character long and may not contain '@' characters."])
		return
	elseif private.settingsDB:ProfileExists(profileName) then
		ChatMessage.PrintUser(L["A profile with this name already exists."])
		return
	end
	private.settingsDB:SetProfile(profileName)
	input:GetBaseElement():GetElement("content.settings.contentFrame.content"):ReloadContent()
end

function private.AccountSyncRowOnEnter(frame)
	local account = frame:GetContext()
	if account then
		frame:GetElement("sendProfileBtn"):Show()
		frame:GetElement("removeBtn"):Show()
	end
	frame:SetRoundedBackgroundColor("ACTIVE_BG")
	frame:Draw()
end

function private.AccountSyncRowOnLeave(frame)
	frame:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
	frame:GetElement("sendProfileBtn"):Hide()
	frame:GetElement("removeBtn"):Hide()
	frame:Draw()
end

function private.AccountSyncTextOnEnter(text)
	local account = text:GetParentElement():GetContext()
	local tooltipLines = TempTable.Acquire()
	if account then
		tinsert(tooltipLines, Theme.GetColor("INDICATOR"):ColorText(L["Sync Status"]))
		local mirrorConnected, mirrorSynced = Sync.GetMirrorStatus(account)
		local mirrorStatus = nil
		if not mirrorConnected then
			mirrorStatus = Theme.GetColor("FEEDBACK_RED"):ColorText(L["Not Connected"])
		elseif not mirrorSynced then
			mirrorStatus = Theme.GetColor("FEEDBACK_YELLOW"):ColorText(L["Updating"])
		else
			mirrorStatus = Theme.GetColor("FEEDBACK_GREEN"):ColorText(L["Up to date"])
		end
		tinsert(tooltipLines, L["Inventory / Gold Graph"]..Tooltip.GetSepChar()..mirrorStatus)
		tinsert(tooltipLines, L["Profession Info"]..Tooltip.GetSepChar()..TSM.Crafting.Sync.GetStatus(account))
		tinsert(tooltipLines, L["Purchase / Sale Info"]..Tooltip.GetSepChar()..TSM.Accounting.Sync.GetStatus(account))
	else
		tinsert(tooltipLines, L["Establishing connection..."])
	end
	text:ShowTooltip(table.concat(tooltipLines, "\n"), nil, 52)
	TempTable.Release(tooltipLines)
	private.AccountSyncRowOnEnter(text:GetParentElement())
end

function private.AccountSyncTextOnLeave(text)
	Tooltip.Hide()
	private.AccountSyncRowOnLeave(text:GetParentElement())
end

function private.SendProfileOnClick(button)
	local _, player = Sync.GetConnectionStatus(button:GetParentElement():GetContext())
	if not player then
		return
	end
	TSM.Groups.Sync.SendCurrentProfile(player)
end

function private.SendProfileOnEnter(button)
	button:ShowTooltip(L["Send your active profile to this synced account"])
	private.AccountSyncRowOnEnter(button:GetParentElement())
end

function private.SendProfileOnLeave(button)
	Tooltip.Hide()
	private.AccountSyncRowOnLeave(button:GetParentElement())
end

function private.RemoveAccountSyncOnClick(button)
	Sync.RemoveAccount(button:GetParentElement():GetContext())
	button:GetBaseElement():GetElement("content.settings.contentFrame.content"):ReloadContent()
	Tooltip.Hide()
	ChatMessage.PrintUser(L["Account sync removed. Please delete the account sync from the other account as well."])
end

function private.RemoveAccountOnEnter(button)
	button:ShowTooltip(L["Remove this account sync and all synced data from this account"])
	private.AccountSyncRowOnEnter(button:GetParentElement())
end

function private.RemoveAccountOnLeave(button)
	Tooltip.Hide()
	private.AccountSyncRowOnLeave(button:GetParentElement())
end

function private.NewAccountSyncInputOnEnterPressed(input)
	local character = Ambiguate(input:GetValue(), "none")
	local isConnecting, errType = Sync.EstablishConnection(character)
	if isConnecting then
		ChatMessage.PrintfUser(L["Establishing connection to %s. Make sure that you've entered this character's name on the other account."], character)
		private.SyncConnectionChangedCallback()
	else
		if errType == Sync.CONNECTION_ERROR.NOT_READY then
			ChatMessage.PrintUser(L["TSM is not yet ready to establish a new sync connection. Please try again later."])
		elseif errType == Sync.CONNECTION_ERROR.CURRENT_CHARACTER then
			ChatMessage.PrintUser(L["Sync Setup Error: You entered the name of the current character and not the character on the other account."])
		elseif errType == Sync.CONNECTION_ERROR.NOT_ONLINE then
			ChatMessage.PrintUser(L["Sync Setup Error: The specified player on the other account is not currently online."])
		elseif errType == Sync.CONNECTION_ERROR.ALREADY_KNOWN then
			ChatMessage.PrintUser(L["Sync Setup Error: This character is already part of a known account."])
		elseif errType then
			error("Unknown error type: "..tostring(errType))
		end
		input:SetValue("")
		input:Draw()
	end
	return isConnecting
end
