-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ListDropdown = UIElements.Define("ListDropdown", "BaseDropdown")
ListDropdown:_ExtendStateSchema()
	:AddOptionalStringField("selectedItem")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ListDropdown:__init()
	self.__super:__init()
	self._itemIndexLookup = {}
end

function ListDropdown:Acquire()
	self.__super:Acquire()
	self._state:PublisherForKeys("selectedItem", "hintText")
		:MapWithKeyCoalesced("selectedItem", "hintText")
		:AssignToTableKey(self._state, "currentSelectionStr")
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@return ListDropdown
function ListDropdown:SetItems(items)
	wipe(self._items)
	wipe(self._itemIndexLookup)
	for i, item in ipairs(items) do
		self._items[i] = item
		assert(not self._itemIndexLookup[item])
		self._itemIndexLookup[item] = i
	end
	return self
end

---Set the currently selected item.
---@param item? string The selected item or nil if nothing should be selected
---@param silent boolean Don't call the OnSelectionChanged callback
---@return ListDropdown
function ListDropdown:SetSelectedItem(item, silent)
	self:SetSelectedItemSilent(item)
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
		if self._onSelectionChangedHandler then
			self:_onSelectionChangedHandler()
		end
	end
	return self
end

---Set the currently selected item silently.
---@param item? string The selected item or nil if nothing should be selected
---@return ListDropdown
function ListDropdown:SetSelectedItemSilent(item)
	self._state.selectedItem = item
	return self
end

---Subscribes to a publisher to set the selected item silently.
---@param publisher ReactivePublisher The publisher
---@return ListDropdown
function ListDropdown:SetSelectedItemSilentPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetSelectedItemSilent"))
	return self
end

---Set the currently selected item by key.
---@param index? number The index of the item to be selected (or nil to clear the selection)
---@param silent boolean Don't call the OnSelectionChanged callback
---@return ListDropdown
function ListDropdown:SetSelectedItemByIndex(index, silent)
	assert(not index or self._items[index])
	self:SetSelectedItem(self._items[index], silent)
	return self
end

---Get the currently selected item.
---@return string?
function ListDropdown:GetSelectedItem()
	return self._state.selectedItem
end

---Get the currently selected item.
---@return string?
function ListDropdown:GetSelectedItemIndex()
	return self._state.selectedItem and self._itemIndexLookup[self._state.selectedItem] or nil
end

---Sets the setting info to have the value of the dropdown automatically correspond with the value of a field in a settings table.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return ListDropdown
function ListDropdown:SetSettingInfo(tbl, key)
	if not self._items[tbl[key]] then
		tbl[key] = nil
	end
	self:SetSelectedItemByIndex(tbl[key])
	self._state:PublisherForKeyChange("selectedItem")
		:MapWithLookupTable(self._itemIndexLookup)
		:AssignToTableKey(tbl, key)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ListDropdown.__protected:_CreateDialog()
	return self.__super:_CreateDialog()
		:SetMultiselect(false)
		:SetItems(self._items)
		:SetScript("OnSelectionChanged", self:__closure("_HandleSelectionChanged"))
end

function ListDropdown.__private:_HandleSelectionChanged(selection)
	self:GetBaseElement():HideDialog()
	self:SetSelectedItem(selection)
	self:Draw()
end
