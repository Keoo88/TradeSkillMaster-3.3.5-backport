-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local IgnoredCooldownList = UIElements.Define("IgnoredCooldownList", "List")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function IgnoredCooldownList:__init()
	self.__super:__init()
	self._query = nil
	self._characterKey = {}
	self._craftString = {}
	self._text = {}
	self._onRemoveCooldown = nil
end

function IgnoredCooldownList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function IgnoredCooldownList:Release()
	local query = self._query
	self._query = nil
	wipe(self._characterKey)
	wipe(self._craftString)
	wipe(self._text)
	self._onRemoveCooldown = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return IgnoredCooldownList
function IgnoredCooldownList:SetQuery(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Registers a script handler.
---@param script "OnRemoveCooldown" The script to register for
---@param handler fun(list: IgnoredCooldownList, ...) The script handler which will be passed any arguments to the script
---@return IgnoredCooldownList
function IgnoredCooldownList:SetScript(script, handler)
	if script == "OnRemoveCooldown" then
		self._onRemoveCooldown = handler
	else
		error("Unknown IgnoredCooldownList script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function IgnoredCooldownList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._characterKey)
	wipe(self._craftString)
	wipe(self._text)
	for _, row in self._query:Iterator() do
		local characterKey, craftString, name = row:GetFields("characterKey", "craftString", "name")
		tinsert(self._characterKey, characterKey)
		tinsert(self._craftString, craftString)
		tinsert(self._text, characterKey.." - "..name)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("BODY_BODY3")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function IgnoredCooldownList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if self._onRemoveCooldown then
		self:_onRemoveCooldown(self._characterKey[dataIndex], self._craftString[dataIndex])
	end
end
