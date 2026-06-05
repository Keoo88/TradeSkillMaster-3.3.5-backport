-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local CategoryCache = LibTSMService:Init("Profession.CategoryCache")
local State = LibTSMService:Include("Profession.State")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {
	parent = {},
	numIndents = {},
	name = {},
	currentSkillLevel = {},
	maxSkillLevel = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CategoryCache:OnModuleLoad(function()
	if not LibTSMService.IsRetail() then
		State.RegisterCallback(function()
			wipe(private.numIndents)
		end)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the parent category ID.
---@param categoryId number The category ID
---@return number?
function CategoryCache.GetParent(categoryId)
	private.Populate(categoryId)
	return private.parent[categoryId]
end

---Gets the number of indents for the category.
---@param categoryId number The category ID
---@return number
function CategoryCache.GetNumIndents(categoryId)
	private.Populate(categoryId)
	return private.numIndents[categoryId]
end

---Gets the name of the category
---@param categoryId number The category ID
---@return string
function CategoryCache.GetName(categoryId)
	private.Populate(categoryId)
	return private.name[categoryId]
end

---Gets the skill level info for the category.
---@param categoryId number The category ID
---@return number? currentSkillLevel
---@return number? maxSkillLevel
function CategoryCache.GetSkillLevel(categoryId)
	private.Populate(categoryId)
	return private.currentSkillLevel[categoryId], private.maxSkillLevel[categoryId]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Populate(categoryId)
	-- numIndents always gets set, so use that to know whether or not this category is already cached
	if private.numIndents[categoryId] then
		return
	end
	local name, numIndents, parentCategoryId, currentSkillLevel, maxSkillLevel = TradeSkill.CategoryInfo(categoryId)
	private.name[categoryId] = name
	private.numIndents[categoryId] = numIndents
	private.parent[categoryId] = parentCategoryId
	private.currentSkillLevel[categoryId] = currentSkillLevel
	private.maxSkillLevel[categoryId] = maxSkillLevel
end
