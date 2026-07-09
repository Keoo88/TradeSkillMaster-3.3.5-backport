-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local TooltipScanning = LibTSMWoW:Init("Service.TooltipScanning")
local Container = LibTSMWoW:Include("API.Container")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local private = {
	tooltip = nil
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets whether or not there are used charges for an item in the inventory (can not be used on clients with C_TooltipInfo).
---@param bag number The bag index
---@param slot number The slot index
---@return boolean
function TooltipScanning.HasUsedCharges(bag, slot)
	assert(not ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO))
	local itemId = Container.GetItemId(bag, slot)
	if not itemId then
		-- No item in this slot
		return false
	end

	-- Check if the item has max charges
	local info = private.SetItemId(itemId)
	local maxCharges = private.ScanTooltipCharges(info)
	if not maxCharges then
		return false
	end

	-- Check if there are used charges on the container item
	info = private.SetContainerItem(bag, slot)
	if maxCharges and private.ScanTooltipCharges(info) ~= maxCharges then
		return true
	end
	return false
end

---Gets whether or not an item in a container slot is soulbound or account bound.
---3.3.5: native GetContainerItemInfo() does not report bound status, so we scan
---the item tooltip for the (localized) soulbound / account-bound lines instead.
---@param bag number The bag index
---@param slot number The slot index
---@return boolean
function TooltipScanning.IsBound(bag, slot)
	local itemId = Container.GetItemId(bag, slot)
	if not itemId then
		-- No item in this slot
		return false
	end
	local info = private.SetContainerItem(bag, slot)
	for _, text in private.TooltipLineIterator(info) do
		if text == ITEM_SOULBOUND or text == ITEM_ACCOUNTBOUND or text == ITEM_BNETACCOUNTBOUND or text == ITEM_BIND_TO_ACCOUNT or text == ITEM_BIND_TO_BNETACCOUNT then
			return true
		end
	end
	return false
end

---Gets the max unique quantity of an item in the inbox.
---@param index number The index
---@param attachIndex number The attachment index
---@return number
function TooltipScanning.GetInboxMaxUnique(index, attachIndex)
	attachIndex = attachIndex or 1

	local speciesId, info = nil, nil
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		info = private.SetInboxItem(index, attachIndex)
		speciesId = info.battlePetSpeciesID
	else
		speciesId = private.SetInboxItem(index, attachIndex)
	end
	if speciesId and speciesId > 0 then
		-- No max for battle pets
		return 0
	end

	for _, text in private.TooltipLineIterator(info) do
		if text == PROFESSIONS_MODIFIED_CRAFTING_REAGENT_BASIC then
			return 0
		elseif text == ITEM_UNIQUE then
			return 1
		else
			local match = strmatch(text, "^"..ITEM_UNIQUE.." %((%d+)%)$")
			if match then
				return tonumber(match)
			end
		end
	end

	return 0
end

---Gets battle pet info for an inbox item.
---@param index number The index
---@param attachIndex number The attachment index
---@return number speciesId
---@return number level
---@return number quality
function TooltipScanning.GetInboxBattlePetInfo(index, attachIndex)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		local info = private.SetInboxItem(index, attachIndex)
		return info.battlePetSpeciesID, info.battlePetLevel, info.battlePetBreedQuality
	else
		return private.SetInboxItem(index, attachIndex)
	end
end

---Gets battlepet info for a guild bank slot.
---@param tab number The tab
---@param slot number The slot
---@return number? speciesId
---@return number? level
---@return number? quality
function TooltipScanning.GetGuildBankBattlePetInfo(tab, slot)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		local info = private.SetGuildBankItem(tab, slot)
		if not info then
			return nil, nil, nil
		end
		return info.battlePetSpeciesID, info.battlePetLevel, info.battlePetBreedQuality
	else
		return private.SetGuildBankItem(tab, slot)
	end
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SetContainerItem(bag, slot)
	private.PrepareTooltip()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		local info = nil
		if ClientInfo.IsRetail() then
			info = C_TooltipInfo.GetBagItem(bag, slot)
		else
			if bag == BANK_CONTAINER then
				info = C_TooltipInfo.GetInventoryItem("player", BankButtonIDToInvSlotID(slot), true)
			else
				info = C_TooltipInfo.GetBagItem(bag, slot)
			end
		end
		return info
	else
		if ClientInfo.IsRetail() then
			private.tooltip:SetBagItem(bag, slot)
		else
			if bag == BANK_CONTAINER then
				private.tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
			else
				private.tooltip:SetBagItem(bag, slot)
			end
		end
	end
end

function private.SetItemId(itemId)
	private.PrepareTooltip()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		return C_TooltipInfo.GetItemByID(itemId)
	elseif private.tooltip.SetItemByID then
		private.tooltip:SetItemByID(itemId)
	else
		-- 3.3.5: no SetItemByID, fall back to SetHyperlink with constructed item link.
		-- 3.3.5 crash guard: SetHyperlink for an item the client has never seen forces
		-- a server item query mid-render and can hard-crash the client (Error #132).
		-- Only scan the tooltip if the item is already in the local cache; an uncached
		-- item would produce an empty/incomplete tooltip anyway.
		if GetItemInfo(itemId) then
			pcall(private.tooltip.SetHyperlink, private.tooltip, "item:"..itemId)
		end
	end
end

function private.SetInboxItem(index, attachIndex)
	private.PrepareTooltip()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		return C_TooltipInfo.GetInboxItem(index, attachIndex)
	else
		return select(2, private.tooltip:SetInboxItem(index, attachIndex))
	end
end

function private.SetGuildBankItem(tab, slot)
	private.PrepareTooltip()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		return C_TooltipInfo.GetGuildBankItem(tab, slot)
	else
		return private.tooltip:SetGuildBankItem(tab, slot)
	end
end

function private.PrepareTooltip()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		return
	end
	private.tooltip = private.tooltip or CreateFrame("GameTooltip", "TSMScanTooltip", UIParent, "GameTooltipTemplate")
	private.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	private.tooltip:ClearLines()
end

function private.ScanTooltipCharges(info)
	for _, text in private.TooltipLineIterator(info) do
		if text == PROFESSIONS_MODIFIED_CRAFTING_REAGENT_BASIC then
			return false
		end
		local maxCharges = nil
		if strfind(ITEM_SPELL_CHARGES, ":") then
			maxCharges = tonumber(strmatch(text, "^(%d+) "..strmatch(ITEM_SPELL_CHARGES, "\1244.+:(.+);").."$")) or tonumber(strmatch(text, "^(%d+) "..strmatch(ITEM_SPELL_CHARGES, "\1244(.+):.+;").."$"))
		else
			maxCharges = tonumber(strmatch(text, "^(%d+)"..strmatch(ITEM_SPELL_CHARGES, "%%d(.+)").."$"))
		end
		if maxCharges then
			return maxCharges
		end
	end
	return false
end

function private.TooltipLineIterator(info)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
		assert(info)
		return private.TooltipLineIteratorHelper, info, 1
	else
		assert(not info)
		return private.TooltipLineIteratorHelper, nil, 1
	end
end

function private.TooltipLineIteratorHelper(info, index)
	while true do
		index = index + 1
		local numLines = ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) and #info.lines or private.tooltip:NumLines()
		if index > numLines then
			return
		end
		local text = nil
		if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TOOLTIP_INFO) then
			text = info.lines[index].leftText
		else
			local tooltipText = _G["TSMScanTooltipTextLeft"..index]
			text = strtrim(tooltipText and tooltipText:GetText() or "")
		end
		if text and text ~= "" then
			return index, text
		end
	end
end
