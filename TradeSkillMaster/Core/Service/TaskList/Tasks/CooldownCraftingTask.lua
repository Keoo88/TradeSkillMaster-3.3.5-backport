-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local LibTSMClass = LibStub("LibTSMClass")
local CooldownCraftingTask = LibTSMClass.DefineClass("CooldownCraftingTask", TSM.TaskList.CraftingTask)
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Profession = TSM.LibTSMService:Include("Profession")
local AddonSettings = TSM.LibTSMApp:Include("Service.AddonSettings")
TSM.TaskList.CooldownCraftingTask = CooldownCraftingTask
local private = {
	didModuleInit = false,
	settings = nil,
	activeTasks = {},
}



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function CooldownCraftingTask.__init(self)
	self.__super:__init()
	if not private.didModuleInit then
		private.didModuleInit = true
		private.settings = AddonSettings.GetDB():NewView()
			:AddKey("char", "internalData", "craftingCooldowns")
		TSM.Crafting.CreateIgnoredCooldownQuery()
			:SetUpdateCallback(private.UpdateTasks)
	end
end

function CooldownCraftingTask.Acquire(self, ...)
	self.__super:Acquire(...)
	private.activeTasks[self] = true
end

function CooldownCraftingTask.Release(self)
	self.__super:Release()
	private.activeTasks[self] = nil
end

function CooldownCraftingTask.CanHideSubTasks(self)
	return true
end

function CooldownCraftingTask.HideSubTask(self, index)
	TSM.Crafting.IgnoreCooldown(self._craftStrings[index])
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CooldownCraftingTask._UpdateState(self)
	local result = self.__super:_UpdateState()
	if not self:HasCraftStrings() then
		return result
	end
	for i = #self._craftStrings, 1, -1 do
		if self:_IsOnCooldown(self._craftStrings[i]) or TSM.Crafting.IsCooldownIgnored(self._craftStrings[i]) then
			self:_RemoveCraftString(self._craftStrings[i])
		end
	end
	if not self:HasCraftStrings() then
		self:_doneHandler()
		return true
	end
	return result
end

function CooldownCraftingTask._IsOnCooldown(self, craftString)
	assert(not private.settings.craftingCooldowns[craftString])
	local remainingCooldown = Profession.GetRemainingCooldown(craftString)
	if remainingCooldown then
		private.settings.craftingCooldowns[craftString] = time() + Math.Round(remainingCooldown)
		return true
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateTasks()
	for task in pairs(private.activeTasks) do
		if task:HasCraftStrings() then
			task:Update()
		end
	end
end
