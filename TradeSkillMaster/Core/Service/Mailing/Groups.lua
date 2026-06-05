-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Groups = TSM.Mailing:NewPackage("Groups") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Group = TSM.LibTSMTypes:Include("Group")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Threading = TSM.LibTSMTypes:Include("Threading")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local MailingOperation = TSM.LibTSMSystem:Include("MailingOperation")
local private = {
	thread = nil,
	settings = nil,
	sendDone = false,
	groupListTemp = {},
	numMailableTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Groups.OnInitialize(settingsDB)
	private.thread = Threading.New("MAIL_GROUPS", private.GroupsMailThread)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mailingOptions", "resendDelay")
end

function Groups.KillThread()
	Threading.Kill(private.thread)
end

function Groups.StartSending(callback, groupList, sendRepeat, isDryRun)
	wipe(private.groupListTemp)
	for _, groupPath in ipairs(groupList) do
		-- TODO: Support the base group
		if groupPath ~= Group.GetRootPath() then
			tinsert(private.groupListTemp, groupPath)
		end
	end
	Threading.Kill(private.thread)
	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, private.groupListTemp, sendRepeat, isDryRun)
end



-- ============================================================================
-- Group Sending Thread
-- ============================================================================

function private.GroupsMailThread(groupList, sendRepeat, isDryRun)
	while true do
		local targets = Threading.AcquireSafeTempTable()
		assert(not next(private.numMailableTemp))
		for _, groupPath in ipairs(groupList) do
			for _, target, itemString, quantity in MailingOperation.SendItemIterator(groupPath, private.GetNumMailable) do
				targets[target] = targets[target] or Threading.AcquireSafeTempTable()
				targets[target][itemString] = quantity
			end
		end
		wipe(private.numMailableTemp)

		if not next(targets) then
			ChatMessage.PrintUser(L["Nothing to send."])
		end
		for name, items in pairs(targets) do
			private.SendItems(name, items, isDryRun)
			TempTable.Release(items)
			Threading.Sleep(0.5)
		end

		TempTable.Release(targets)

		if sendRepeat then
			Threading.Sleep(private.settings.resendDelay * 60)
		else
			break
		end
	end
end

function private.GetNumMailable(itemString)
	private.numMailableTemp[itemString] = private.numMailableTemp[itemString] or BagTracking.GetNumMailable(itemString)
	return private.numMailableTemp[itemString]
end

function private.SendItems(target, items, isDryRun)
	private.sendDone = false
	TSM.Mailing.Send.StartSending(private.SendCallback, target, "", "", 0, items, true, isDryRun)
	while not private.sendDone do
		Threading.Yield(true)
	end
end

function private.SendCallback()
	private.sendDone = true
end
