-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Database = LibTSMUI:From("LibTSMUtil"):Include("Database")
local DEFAULT_COL_WIDTH = 100



-- ============================================================================
-- Element Definition
-- ============================================================================

local DatabaseBrowseScrollTable = UIElements.Define("DatabaseBrowseScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DatabaseBrowseScrollTable:__init()
	self.__super:__init({})
	self._query = nil
	self._fieldQuery = nil
	self._rawSettings = {
		cols = {},
	}
	self._defaultSettings = {
		cols = {},
	}
	self._recycledCells = {}
end

function DatabaseBrowseScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
end

function DatabaseBrowseScrollTable:Release()
	local query = self._query
	self._query = nil
	if self._fieldQuery then
		self._fieldQuery:Release()
		self._fieldQuery = nil
	end
	wipe(self._rawSettings.cols)
	wipe(self._defaultSettings.cols)
	for _, cell in pairs(self._header.cells) do
		cell:Hide()
		tinsert(self._recycledCells, cell)
	end
	wipe(self._header.cells)
	wipe(self._colInfo)
	self.__super:Release()
	wipe(self._data)
	if query then
		query:Release()
	end
end

---@private
function DatabaseBrowseScrollTable:SetSettings()
	error("Not supported for DatabaseBrowseScrollTable")
end

---Sets the DB table to browse.
---@param name string The name of the table
---@return DatabaseBrowseScrollTable
function DatabaseBrowseScrollTable:SetTable(name)
	assert(not self._query and not self._fieldQuery)
	local query = Database.CreateDBQuery(name)
	local fieldQuery = Database.CreateInfoFieldQuery(name)
		:Select("field")
		:OrderBy("order", true)
	self._query = query
	self._fieldQuery = fieldQuery

	for _, field in fieldQuery:Iterator() do
		tinsert(self._rawSettings.cols, { id = field, width = DEFAULT_COL_WIDTH, hidden = nil })
		tinsert(self._defaultSettings.cols, { id = field, width = DEFAULT_COL_WIDTH, hidden = nil })
		local info = {
			title = field,
			justifyH = "LEFT",
			font = "BODY_BODY3",
			hasTooltip = true,
			disableTooltipLinking = true,
		}
		self._colInfo[field] = info
		local cell = tremove(self._recycledCells) or self:_CreateHeaderCell(info)
		self._header.cells[field] = cell
		cell.titleText:SetText(info.title)
		cell.resizerHighlight:TSMSubscribeColorTexture("ACTIVE_BG+HOVER")
		cell.sepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
		self._data[field] = {}
		self._data[field.."_tooltip"] = {}
	end
	self:_DrawHeader()

	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Updates the data from the query.
---@param codeStr string The code to lua and execute
function DatabaseBrowseScrollTable:UpdateQueryWithLoadedFunction(codeStr)
	local func, errStr = loadstring(codeStr)
	if not func then
		ChatMessage.PrintfUser("Failed to compile code: "..errStr)
		return
	end
	self._query:Reset()
	setfenv(func, { query = self._query })
	local ok, funcErrStr = pcall(func)
	if not ok then
		ChatMessage.PrintfUser("Failed to execute code: "..funcErrStr)
		self._query:Reset()
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function DatabaseBrowseScrollTable.__protected:_GetSettingsValue()
	return self._rawSettings
end

function DatabaseBrowseScrollTable.__protected:_GetSettingsDefaultReadOnly()
	return self._defaultSettings
end

function DatabaseBrowseScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		for field in pairs(self._colInfo) do
			local value = strjoin(",", tostringall(row:GetField(field)))
			tinsert(self._data[field], value)
			if not strmatch(value, ",") and (strmatch(value, "item:") or strmatch(value, "battlepet:") or strmatch(value, "[ip]:")) then
				-- This is an item string or item link
				tinsert(self._data[field.."_tooltip"], value)
			else
				tinsert(self._data[field.."_tooltip"], "Value: "..value)
			end
		end
	end
	self:_SetNumRows(self._query:Count())
	self:Draw()
end
