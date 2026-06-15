local Spell = Spell or {}
local SpellMixin = SpellMixin or {}
local C_Spell = C_Spell

--[[static]] function Spell:CreateFromSpellID(spellID)
	local spell = CreateFromMixins(SpellMixin)
	spell:SetSpellID(spellID)
	return spell
end

function SpellMixin:SetSpellID(spellID)
	--self:Clear()
	self.spellID = spellID
end

function SpellMixin:GetSpellID()
	return self.spellID
end

function SpellMixin:Clear()
	self.spellID = nil
end

function SpellMixin:IsSpellEmpty()
	return not self:GetSpellID()
	--[[local spellID = self:GetSpellID()
	return not spellID or not C_Spell.DoesSpellExist(spellID)]]
end

-- Spell API
function SpellMixin:IsSpellDataCached()
	--[[if not self:IsSpellEmpty() then
		return C_Spell.IsSpellDataCached(self:GetSpellID())
	end
	return true]]
end

function SpellMixin:IsDataEvictable()
	-- Spell data could be evicted from the cache
	return true
end

function SpellMixin:GetSpellName()
	return GetSpellInfo(self:GetSpellID())
end

function SpellMixin:GetSpellTexture()
	return C_Spell.GetSpellTexture(self:GetSpellID())
end

function SpellMixin:GetSpellSubtext()
	return C_Spell.GetSpellSubtext(self:GetSpellID())
end

function SpellMixin:GetSpellDescription()
	return C_Spell.GetSpellDescription(self:GetSpellID())
end

-- Add a callback to be executed when spell data is loaded, if the spell data is already loaded then execute it immediately
function SpellMixin:ContinueOnSpellLoad(callbackFunction)
	if type(callbackFunction) ~= "function" or self:IsSpellEmpty() then
		error("Usage: NonEmptySpell:ContinueOnLoad(callbackFunction)", 2)
	end

	--SpellEventListener:AddCallback(self:GetSpellID(), callbackFunction)
	-- TODO: for performance, we need to delay this until in the world
	callbackFunction()
end

-- Same as ContinueOnSpellLoad, except it returns a function that when called will cancel the continue
function SpellMixin:ContinueWithCancelOnSpellLoad(callbackFunction)
	--[[if type(callbackFunction) ~= "function" or self:IsSpellEmpty() then
		error("Usage: NonEmptySpell:ContinueWithCancelOnSpellLoad(callbackFunction)", 2)
	end

	return SpellEventListener:AddCancelableCallback(self:GetSpellID(), callbackFunction)]]
end

-- Generic aliases for use with ContinuableContainer
function SpellMixin:ContinueWithCancelOnRecordLoad(callbackFunction)
	return self:ContinueWithCancelOnSpellLoad(callbackFunction)
end

function SpellMixin:IsRecordDataCached()
	return self:IsSpellDataCached()
end

-- Global
_G.Spell = Spell
_G.SpellMixin = SpellMixin