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

local Spacer = UIElements.Define("Spacer", "Element")



-- ============================================================================
-- Spacer Frame Class
-- ============================================================================

---@class SpacerFrame
local SpacerFrame = {}

function SpacerFrame:SetParent(parent)
	self._parent = parent
end

function SpacerFrame:GetParent()
	return self._parent
end

function SpacerFrame:SetScale(scale)
	self._scale = scale
end

function SpacerFrame:GetScale()
	return self._scale
end

function SpacerFrame:SetWidth(width)
	self._width = width
end

function SpacerFrame:GetWidth()
	return self._width
end

function SpacerFrame:SetHeight(height)
	self._height = height
end

function SpacerFrame:GetHeight()
	return self._height
end

function SpacerFrame:Show()
	self._visible = true
end

function SpacerFrame:Hide()
	self._visible = false
end

function SpacerFrame:IsVisible()
	return self._visible
end

function SpacerFrame:ClearAllPoints()
	-- Do nothing
end

function SpacerFrame:SetPoint(...)
	-- Do nothing
end

function SpacerFrame:TSMSetDebugObject()
	-- Do nothing
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Spacer:__init()
	local frame = {
		_parent = nil,
		_scale = 1,
		_width = 0,
		_height = 0,
		_visible = false,
	}
	for k, v in pairs(SpacerFrame) do
		frame[k] = v
	end
	self.__super:__init(frame)
end
