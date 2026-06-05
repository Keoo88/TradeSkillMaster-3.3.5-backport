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

local OperationCollapsibleContainer = UIElements.Define("OperationCollapsibleContainer", "CollapsibleContainer")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationCollapsibleContainer:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("Text", "description")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 12)
		:SetFont("BODY_BODY3")
	)
end

---Sets the heading and description label text.
---@param heading string The heading
---@param description string The description
---@return OperationCollapsibleContainer
function OperationCollapsibleContainer:SetHeadingDescription(heading, description)
	self:SetHeadingText(heading)
	self:GetElement("content.description"):SetText(description)
	return self
end
