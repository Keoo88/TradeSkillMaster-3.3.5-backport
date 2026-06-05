-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local State = LibTSMService:Init("Profession.State")
local FSM = LibTSMService:From("LibTSMUtil"):Include("FSM")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	fsm = nil,
	callbacks = {},
	isClosed = true,
	craftOpen = nil,
	tradeSkillOpen = nil,
	professionName = nil,
	skillId = nil,
	readyTimer = nil,
}
local WAIT_FRAME_DELAY = 5



-- ============================================================================
-- Module Loading
-- ============================================================================

State:OnModuleLoad(function()
	private.CreateFSM()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Register a callback for when the profesison state changes.
---@param callback fun()
function State.RegisterCallback(callback)
	tinsert(private.callbacks, callback)
end

---Returns whether or not the profession is currently open.
---@return boolean
function State.IsClosed()
	return private.isClosed
end

---Sets whether or not classic crafting is open.
---@param open boolean
---TODO: Better way to handle this
function State.SetClassicCraftingOpen(open)
	assert(not LibTSMService.IsRetail())
	private.craftOpen = open
end

---Gets the current profession name and skillId (if available).
---@return string?
---@return Enum.Profession?
function State.GetCurrentProfession()
	return private.professionName, private.skillId
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.CreateFSM()
	private.readyTimer = DelayTimer.New("PROFESSION_STATE_READY", function()
		private.readyTimer:RunForFrames(WAIT_FRAME_DELAY)
		private.fsm:ProcessEvent("EV_FRAME_DELAY")
	end)
	TradeSkill.LoadBlizzardCraftUI()
	Event.Register("TRADE_SKILL_SHOW", function()
		private.tradeSkillOpen = true
		private.fsm:ProcessEvent("EV_TRADE_SKILL_SHOW")
		private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGING")
		private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGED")
	end)
	Event.Register("TRADE_SKILL_CLOSE", function()
		private.tradeSkillOpen = false
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) and not private.craftOpen then
			private.fsm:ProcessEvent("EV_TRADE_SKILL_CLOSE")
		end
	end)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
		Event.Register("GARRISON_TRADESKILL_NPC_CLOSED", function()
			private.fsm:ProcessEvent("EV_TRADE_SKILL_CLOSE")
		end)
		Event.Register("TRADE_SKILL_DATA_SOURCE_CHANGED", function()
			private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGED")
		end)
		Event.Register("TRADE_SKILL_DATA_SOURCE_CHANGING", function()
			private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGING")
		end)
	else
		Event.Register("CRAFT_SHOW", function()
			private.craftOpen = true
			private.fsm:ProcessEvent("EV_TRADE_SKILL_SHOW")
			private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGING")
			private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGED")
		end)
		Event.Register("CRAFT_CLOSE", function()
			private.craftOpen = false
			if not private.tradeSkillOpen then
				private.fsm:ProcessEvent("EV_TRADE_SKILL_CLOSE")
			end
		end)
		Event.Register("CRAFT_UPDATE", function()
			private.fsm:ProcessEvent("EV_TRADE_SKILL_DATA_SOURCE_CHANGED")
		end)
	end
	private.fsm = FSM.New("PROFESSION_STATE")
		:AddState(FSM.NewState("ST_CLOSED")
			:SetOnEnter(function()
				private.isClosed = true
				private.RunCallbacks()
			end)
			:SetOnExit(function()
				private.isClosed = false
				private.RunCallbacks()
			end)
			:AddTransition("ST_WAITING_FOR_DATA")
			:AddEventTransition("EV_TRADE_SKILL_SHOW", "ST_WAITING_FOR_DATA")
		)
		:AddState(FSM.NewState("ST_WAITING_FOR_DATA")
			:AddTransition("ST_WAITING_FOR_READY")
			:AddTransition("ST_CLOSED")
			:AddEventTransition("EV_TRADE_SKILL_DATA_SOURCE_CHANGED", "ST_WAITING_FOR_READY")
			:AddEventTransition("EV_TRADE_SKILL_CLOSE", "ST_CLOSED")
		)
		:AddState(FSM.NewState("ST_WAITING_FOR_READY")
			:SetOnEnter(function()
				private.readyTimer:RunForFrames(WAIT_FRAME_DELAY)
			end)
			:SetOnExit(function()
				private.readyTimer:Cancel()
			end)
			:AddTransition("ST_SHOWN")
			:AddTransition("ST_DATA_CHANGING")
			:AddTransition("ST_CLOSED")
			:AddEvent("EV_FRAME_DELAY", function()
				if TradeSkill.IsDataReady() then
					return "ST_SHOWN"
				end
			end)
			:AddEventTransition("EV_TRADE_SKILL_DATA_SOURCE_CHANGING", "ST_DATA_CHANGING")
			:AddEventTransition("EV_TRADE_SKILL_CLOSE", "ST_CLOSED")
		)
		:AddState(FSM.NewState("ST_SHOWN")
			:SetOnEnter(function()
				local name, skillId = TradeSkill.GetName()
				assert(name)
				Log.Info("Showing profession: %s (%s)", name, tostring(skillId))
				private.professionName = name
				private.skillId = skillId
				private.RunCallbacks()
			end)
			:SetOnExit(function()
				private.professionName = nil
				private.skillId = nil
				private.RunCallbacks()
			end)
			:AddTransition("ST_DATA_CHANGING")
			:AddTransition("ST_CLOSED")
			:AddEventTransition("EV_TRADE_SKILL_DATA_SOURCE_CHANGING", "ST_DATA_CHANGING")
			:AddEventTransition("EV_TRADE_SKILL_CLOSE", "ST_CLOSED")
		)
		:AddState(FSM.NewState("ST_DATA_CHANGING")
			:AddTransition("ST_WAITING_FOR_READY")
			:AddTransition("ST_CLOSED")
			:AddEventTransition("EV_TRADE_SKILL_DATA_SOURCE_CHANGED", "ST_WAITING_FOR_READY")
			:AddEventTransition("EV_TRADE_SKILL_CLOSE", "ST_CLOSED")
		)
		:Init("ST_CLOSED")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RunCallbacks()
	for _, callback in ipairs(private.callbacks) do
		callback()
	end
end
