-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Commands = TSM.UI:NewPackage("Commands") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ObjectPool = TSM.LibTSMUtil:IncludeClassType("ObjectPool")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local SlashCommands = TSM.LibTSMApp:Include("Service.SlashCommands")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local private = {
	settingsDB = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

function Commands.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("global", "debug", "chatLoggingEnabled")
		:AddKey("global", "internalData", "whatsNewVersion")
		:AddKey("factionrealm", "internalData", "crafts")

	-- Slash commands
	SlashCommands.RegisterBase(TSM.MainUI.Toggle, L["Toggles the main TSM window"])
	SlashCommands.Register("version", private.PrintVersions, L["Prints out the version numbers of all installed modules"])
	SlashCommands.Register("sources", private.PrintSources, L["Prints out the available price sources for use in custom prices"])
	SlashCommands.Register("price", private.TestPriceSource, L["Allows for testing of custom prices"])
	SlashCommands.Register("profile", private.ChangeProfile, L["Changes to the specified profile (i.e. '/tsm profile Default' changes to the 'Default' profile)"])
	SlashCommands.Register("destroy", TSM.UI.DestroyingUI.Toggle, L["Opens the Destroying frame if there are items in your bags to be destroyed."])
	SlashCommands.Register("crafting", TSM.UI.CraftingUI.Toggle, L["Toggles the TSM Crafting UI."])
	SlashCommands.Register("tasklist", TSM.UI.TaskListUI.Toggle, L["Toggles the TSM Task List UI"])
	SlashCommands.Register("bankui", TSM.UI.BankingUI.Toggle, L["Toggles the TSM Banking UI if either the bank or guild bank is currently open."])
	SlashCommands.Register("get", TSM.Banking.GetByFilter, L["Gets items from the bank or guild bank matching the item or partial text entered."])
	SlashCommands.Register("put", TSM.Banking.PutByFilter, L["Puts items matching the item or partial text entered into the bank or guild bank."])
	SlashCommands.Register("restock_help", TSM.Crafting.RestockHelp, L["Tells you why a specific item is not being restocked and added to the queue."])
	SlashCommands.RegisterDebug("logging", private.ToggleLogging)
	SlashCommands.RegisterDebug("clearcraftdb", private.ClearCraftDB)
	SlashCommands.RegisterDebug("leaks", private.EnableLeakDebug)
	SlashCommands.RegisterDebug("whatsnew", private.ResetWhatsNew)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PrintVersions()
	ChatMessage.PrintUser(L["TSM Version Info:"])
	ChatMessage.PrintUserRaw("TradeSkillMaster "..ChatMessage.ColorUserAccentText(TSM.LibTSMUtil.GetVersionStr()))
	local appHelperVersion = C_AddOns.GetAddOnMetadata("TradeSkillMaster_AppHelper", "Version")
	if appHelperVersion then
		-- use strmatch so that our sed command doesn't replace this string
		if strmatch(appHelperVersion, "^@tsm%-project%-version@$") then
			appHelperVersion = "Dev"
		end
		ChatMessage.PrintUserRaw("TradeSkillMaster_AppHelper "..ChatMessage.ColorUserAccentText(appHelperVersion))
	end
end

function private.PrintSources()
	ChatMessage.PrintUser(L["Below is a list of all available price sources, along with a brief description of what they represent."])
	local moduleList = TempTable.Acquire()
	for _, _, _, moduleName in CustomString.SourceIterator() do
		if not moduleList[moduleName] then
			moduleList[moduleName] = true
			tinsert(moduleList, moduleName)
		end
	end
	sort(moduleList)
	for _, module in ipairs(moduleList) do
		ChatMessage.PrintUserRaw("|cffffff00"..module..":|r")
		local lines = TempTable.Acquire()
		for _, key, label, moduleName in CustomString.SourceIterator() do
			if moduleName == module then
				tinsert(lines, format("  %s (%s)", ChatMessage.ColorUserAccentText(key), label))
			end
		end
		sort(lines)
		for _, line in ipairs(lines) do
			ChatMessage.PrintfUserRaw(line)
		end
		TempTable.Release(lines)
	end
	TempTable.Release(moduleList)
end

function private.TestPriceSource(price)
	local _, endIndex, link = strfind(price, "(\124c[0-9a-f]+\124H[^\124]+\124h%[[^%]]+%]\124h\124r)")
	if not link then
		_, endIndex, link = strfind(price, "(\124cnIQ[0-9]:\124H[^\124]+\124h%[[^%]]+%]\124h\124r)")
	end
	price = link and strtrim(strsub(price, endIndex + 1))
	if not price or price == "" then
		ChatMessage.PrintUser(L["Usage: /tsm price <Item Link> <Custom String>"])
		return
	end

	local isValid, err = CustomPrice.Validate(price)
	if not isValid then
		ChatMessage.PrintfUser(L["%s is not a valid custom price and gave the following error: %s"], ChatMessage.ColorUserAccentText(price), err)
		return
	end

	local itemString = ItemString.Get(link)
	if not itemString then
		ChatMessage.PrintfUser(L["%s is a valid custom price but %s is an invalid item."], ChatMessage.ColorUserAccentText(price), link)
		return
	end

	local value = CustomString.GetValue(price, itemString)
	if not value then
		ChatMessage.PrintfUser(L["%s is a valid custom price but did not give a value for %s."], ChatMessage.ColorUserAccentText(price), link)
		return
	end

	ChatMessage.PrintfUser(L["A custom price of %s for %s evaluates to %s."], ChatMessage.ColorUserAccentText(price), link, Money.ToStringExact(value))
end

function private.ChangeProfile(targetProfile)
	targetProfile = strtrim(targetProfile)
	if targetProfile == "" then
		ChatMessage.PrintfUser(L["No profile specified. Possible profiles: '%s'"], private.GetProfileListStr())
	else
		for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
			if profile == targetProfile then
				if profile ~= private.settingsDB:GetCurrentProfile() then
					private.settingsDB:SetProfile(profile)
				end
				ChatMessage.PrintfUser(L["Profile changed to '%s'."], profile)
				return
			end
		end
		ChatMessage.PrintfUser(L["Could not find profile '%s'. Possible profiles: '%s'"], targetProfile, private.GetProfileListStr())
	end
end

function private.GetProfileListStr()
	local profiles = TempTable.Acquire()
	for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
		tinsert(profiles, profile)
	end
	local result = table.concat(profiles, "', '")
	TempTable.Release(profiles)
	return result
end

function private.ToggleLogging()
	assert(not TSM.LibTSMUtil.IsTestVersion() and TSM.LibTSMUtil.IsDevVersion())
	private.settings.chatLoggingEnabled = not private.settings.chatLoggingEnabled
	Log.SetLoggingToChatEnabled(private.settings.chatLoggingEnabled)
	if private.settings.chatLoggingEnabled then
		ChatMessage.PrintfUser("Logging to chat enabled")
	else
		ChatMessage.PrintfUser("Logging to chat disabled")
	end
end

function private.ClearCraftDB()
	private.settings.crafts = {}
	ReloadUI()
end

function private.EnableLeakDebug()
	TempTable.EnableLeakDebug()
	ObjectPool.EnableLeakDebug()
end

function private.ResetWhatsNew()
	private.settings.whatsNewVersion = 0
end
