-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDev = select(2, ...).LibTSMDev
local DBViewer = LibTSMDev:Init("DBViewer")
local SlashCommands = LibTSMDev:From("LibTSMApp"):Include("Service.SlashCommands")
local UIElements = LibTSMDev:From("LibTSMUI"):Include("Util.UIElements")
local Database = LibTSMDev:From("LibTSMUtil"):Include("Database")
local private = {
	frame = nil,
	frameContext = {},
	dividedContainerContext = {},
	selectedDBName = nil,
}
local DEFAULT_FRAME_CONTEXT = {
	width = 900,
	height = 600,
	centerX = 100,
	centerY = 0,
	scale = 1,
}
local MIN_FRAME_SIZE = {
	width = 900,
	height = 600
}
local DEFAULT_DIVIDED_CONTAINER_CONTEXT = {
	leftWidth = 200,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

DBViewer:OnModuleLoad(function()
	SlashCommands.RegisterDebug("db", DBViewer.Toggle)
end)

DBViewer:OnModuleUnload(function()
	-- Hide the frame
	if private.frame then
		DBViewer.Toggle()
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function DBViewer.Toggle()
	if not private.frame then
		private.frame = private.CreateMainFrame()
		private.frame:Draw()
		private.frame:Show()
	else
		private.frame:Hide()
		assert(not private.frame)
	end
end



-- ============================================================================
-- UI Functions
-- ============================================================================

function private.CreateMainFrame()
	private.selectedDBName = nil
	return UIElements.New("ApplicationFrame", "base")
		:SetParent(UIParent)
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetContextTable(private.frameContext, DEFAULT_FRAME_CONTEXT)
		:SetStrata("HIGH")
		:SetTitle("TSM DB Viewer")
		:SetScript("OnHide", private.FrameOnHide)
		:SetContentFrame(UIElements.New("DividedContainer", "container")
			:SetContextTable(private.dividedContainerContext, DEFAULT_DIVIDED_CONTAINER_CONTEXT)
			:SetBackgroundColor("PRIMARY_BG")
			:SetMinWidth(100, 100)
			:SetLeftChild(UIElements.New("ScrollFrame", "left")
				:AddChildrenWithFunction(private.AddTableRows)
			)
			:SetRightChild(UIElements.New("Frame", "right")
				:SetLayout("VERTICAL")
			)
		)
end

function private.AddTableRows(frame)
	for _, name in Database.InfoNameIterator() do
		frame:AddChild(UIElements.New("Button", "nav_"..name)
			:SetHeight(20)
			:SetPadding(8, 0, 0, 0)
			:SetFont("BODY_BODY3")
			:SetJustifyH("LEFT")
			:SetBackground("PRIMARY_BG", true)
			:SetText(name)
			:SetScript("OnClick", private.NavButtonOnClick)
		)
	end
end

function private.CreateTableContent()
	local contentFrame = private.frame:GetElement("container.right")
	contentFrame:ReleaseAllChildren()
	contentFrame:AddChild(UIElements.New("TabGroup", "tabs")
		:SetMargin(0, 0, 4, 0)
		:SetNavCallback(private.ContentNavCallback)
		:AddPath("Structure", true)
		:AddPath("Browse")
	)
	contentFrame:Draw()
end

function private.ContentNavCallback(_, path)
	if path == "Structure" then
		return private.CreateStructureFrame()
	elseif path == "Browse" then
		return private.CreateBrowseFrame()
	else
		error("Invalid path: "..tostring(path))
	end
end

function private.CreateStructureFrame()
	return UIElements.New("Frame", "structure")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "info")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(4)
			:AddChild(UIElements.New("Text", "numRows")
				:SetFont("BODY_BODY2")
				:SetText("Total Rows: "..Database.GetNumRows(private.selectedDBName))
			)
			:AddChild(UIElements.New("Text", "numRows")
				:SetFont("BODY_BODY2")
				:SetText("Active Queries: "..Database.GetNumActiveQueries(private.selectedDBName))
			)
		)
		:AddChild(UIElements.New("DatabaseStructureScrollTable", "table")
			:SetQuery(Database.CreateInfoFieldQuery(private.selectedDBName))
		)
end

function private.CreateBrowseFrame()
	return UIElements.New("Frame", "browse")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Input", "queryInput")
			:SetHeight(26)
			:SetMargin(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetValue("query")
			:SetScript("OnEnterPressed", private.QueryInputOnEnterPressed)
		)
		:AddChild(UIElements.New("DatabaseBrowseScrollTable", "table")
			:SetTable(private.selectedDBName)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.FrameOnHide(frame)
	if frame ~= private.frame then return end
	private.frame:Release()
	private.frame = nil
end

function private.NavButtonOnClick(button)
	local navFrame = button:GetParentElement()
	private.selectedDBName = button:GetText()
	for _, name in Database.InfoNameIterator() do
		navFrame:GetElement("nav_"..name)
			:SetTextColor(name == private.selectedDBName and "INDICATOR" or "TEXT")
			:Draw()
	end
	private.CreateTableContent()
end

function private.QueryInputOnEnterPressed(input)
	input:GetElement("__parent.table"):UpdateQueryWithLoadedFunction(input:GetValue())
end
