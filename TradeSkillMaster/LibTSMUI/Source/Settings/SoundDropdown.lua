-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local SoundAlert = LibTSMUI:From("LibTSMWoW"):Include("UI.SoundAlert")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local SoundDropdown = UIElements.Define("SoundDropdown", "BaseDropdown")
SoundDropdown:_ExtendStateSchema()
	:AddStringField("selectedDescription", UIUtils.GetSoundDescription(SoundAlert.NO_SOUND_KEY))
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SoundDropdown:__init()
	self.__super:__init()
	self._keyLookup = {}
end

function SoundDropdown:Acquire()
	self.__super:Acquire()
	self._state:PublisherForKeyChange("selectedDescription")
		:AssignToTableKey(self._state, "currentSelectionStr")
	for _, key in SoundAlert.KeyIterator() do
		local description = UIUtils.GetSoundDescription(key)
		assert(description and key and not self._keyLookup[description] and not Table.KeyByValue(self._keyLookup, key))
		tinsert(self._items, description)
		self._keyLookup[description] = key
	end
	sort(self._items, private.SortHelper)
end

function SoundDropdown:Release()
	wipe(self._keyLookup)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the setting info to have the value of the dropdown automatically correspond with the value of a field in a settings table.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return SoundDropdown
function SoundDropdown:SetSettingInfo(tbl, key)
	self._state.selectedDescription = UIUtils.GetSoundDescription(tbl[key] or SoundAlert.NO_SOUND_KEY)
	self._state:PublisherForKeyChange("selectedDescription")
		:MapWithLookupTable(self._keyLookup)
		:AssignToTableKey(tbl, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SoundDropdown.__protected:_CreateDialog()
	return self.__super:_CreateDialog()
		:SetMultiselect(false)
		:SetItems(self._items)
		:SetScript("OnSelectionChanged", self:__closure("_HandleSelectionChanged"))
end

function SoundDropdown.__private:_HandleSelectionChanged(selection)
	self:GetBaseElement():HideDialog()
	self._state.selectedDescription = selection
	SoundAlert.Play(self._keyLookup[selection])
	self:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SortHelper(a, b)
	local noSoundDesc = UIUtils.GetSoundDescription(SoundAlert.NO_SOUND_KEY)
	if a == noSoundDesc then
		return true
	elseif b == noSoundDesc then
		return false
	else
		return a < b
	end
end
