-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDev = select(2, ...).LibTSMDev
local FrameStack = LibTSMDev:Init("FrameStack")
local SlashCommands = LibTSMDev:From("LibTSMApp"):Include("Service.SlashCommands")
local UIElements = LibTSMDev:From("LibTSMUI"):Include("Util.UIElements")
local ScriptWrapper = LibTSMDev:From("LibTSMWoW"):Include("API.ScriptWrapper")
local Theme = LibTSMDev:From("LibTSMService"):Include("UI.Theme")
local Math = LibTSMDev:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMDev:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMDev:From("LibTSMUtil"):Include("Lua.Vararg")
local private = {
	tooltip = nil,
}
local STRATA_ORDER = {"TOOLTIP", "FULLSCREEN_DIALOG", "FULLSCREEN", "DIALOG", "HIGH", "MEDIUM", "LOW", "BACKGROUND", "WORLD"}
local framesByStrata = {
	WORLD = {},
	BACKGROUND = {},
	LOW = {},
	MEDIUM = {},
	HIGH = {},
	DIALOG = {},
	FULLSCREEN = {},
	FULLSCREEN_DIALOG = {},
	TOOLTIP = {},
}
local ELEMENT_ATTR_KEYS = {
	"_hScrollbar",
	"_vScrollbar",
	"_hScrollFrame",
	"_hContent",
	"_vScrollFrame",
	"_content",
	"_header",
	"_frame",
	"_rows",
}
local COLOR_KEYS = {
	FRAME_BG = true,
	PRIMARY_BG = true,
	PRIMARY_BG_ALT = true,
	ACTIVE_BG = true,
	ACTIVE_BG_ALT = true,
	INDICATOR = true,
	INDICATOR_ALT = true,
	INDICATOR_DISABLED = true,
	TEXT = true,
	TEXT_ALT = true,
	TEXT_DISABLED = true,
	FEEDBACK_RED = true,
	FEEDBACK_YELLOW = true,
	FEEDBACK_GREEN = true,
	FEEDBACK_BLUE = true,
	FEEDBACK_ORANGE = true,
	GROUP_ONE = true,
	GROUP_TWO = true,
	GROUP_THREE = true,
	GROUP_FOUR = true,
	GROUP_FIVE = true,
	FULL_BLACK = true,
	FULL_WHITE = true,
	BLIZZARD_YELLOW = true,
	BLIZZARD_GM = true,
}
local FONT_KEYS = {
	HEADING_H5 = true,
	BODY_BODY1 = true,
	BODY_BODY1_BOLD = true,
	BODY_BODY2 = true,
	BODY_BODY2_MEDIUM = true,
	BODY_BODY2_BOLD = true,
	BODY_BODY3 = true,
	BODY_BODY3_MEDIUM = true,
	ITEM_BODY1 = true,
	ITEM_BODY2 = true,
	ITEM_BODY3 = true,
	TABLE_TABLE1 = true,
}
local ELEMENT_STYLE_KEYS = {
	"_texture",
	"_backgroundColor",
	"_font",
}
local IGNORED_FRAMES = {
	GlobalFXDialogModelScene = true
}



-- ============================================================================
-- Module Loading
-- ============================================================================

FrameStack:OnModuleLoad(function()
	SlashCommands.RegisterDebug("fstack", private.Toggle)
	SlashCommands.RegisterDebug("fstackdump", private.DumpToChat)
	SlashCommands.RegisterDebug("fstackfull", private.DumpFullFrame)
	SlashCommands.RegisterDebug("fstackchildren", private.DumpChildren)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Toggle()
	if not private.tooltip then
		private.tooltip = CreateFrame("GameTooltip", "TSMFrameStackTooltip", UIParent, "GameTooltipTemplate")
		private.tooltip.highlightFrame = CreateFrame("Frame", nil, nil, BackdropTemplateMixin and "BackdropTemplate" or nil)
		private.tooltip.highlightFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		private.tooltip.highlightFrame:SetBackdropColor(1, 0, 0, 0.3)
		private.tooltip:Hide()
		ScriptWrapper.Set(private.tooltip, "OnUpdate", private.OnUpdate)
	end
	if private.tooltip:IsVisible() then
		private.tooltip:Hide()
		private.tooltip.highlightFrame:Hide()
	else
		private.tooltip.lastUpdate = 0
		private.tooltip.altDown = nil
		private.tooltip.index = 1
		private.tooltip.numFrames = 0
		private.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		private.tooltip:SetPoint("TOPLEFT", 0, 0)
		private.tooltip:AddLine("Loading...")
		private.tooltip:Show()
		private.tooltip.highlightFrame:Show()
	end
end

function private.DumpToChat()
	print("=== TSM Frame Stack Dump ===")
	local x, y = GetCursorPosition()
	print(format("Cursor: %.2f, %.2f", x, y))

	for _, strata in ipairs(STRATA_ORDER) do
		wipe(framesByStrata[strata])
	end

	local frame = EnumerateFrames()
	while frame do
		local isForbidden = false
		if frame.IsForbidden then
			local success, result = pcall(frame.IsForbidden, frame)
			isForbidden = success and result
		end
		if not isForbidden and frame:IsVisible() and MouseIsOver(frame) then
			local strata = frame:GetFrameStrata()
			if framesByStrata[strata] then
				tinsert(framesByStrata[strata], frame)
			end
			for _, region in Vararg.Iterator(frame:GetRegions()) do
				local regionForbidden = false
				if region.IsForbidden then
					local success, result = pcall(region.IsForbidden, region)
					regionForbidden = success and result
				end
				if region:IsObjectType("Texture") and not regionForbidden and region:IsVisible() and MouseIsOver(region) then
					if framesByStrata[strata] then
						tinsert(framesByStrata[strata], region)
					end
				end
			end
		end
		frame = EnumerateFrames(frame)
	end

	for _, strata in ipairs(STRATA_ORDER) do
		if #framesByStrata[strata] > 0 then
			sort(framesByStrata[strata], private.FrameLevelSortFunction)
			print(format("|cff9999ff%s|r", strata))
			for _, strataFrame in ipairs(framesByStrata[strata]) do
				local isTexture = strataFrame:IsObjectType("Texture")
				local level = (isTexture and strataFrame:GetParent() or strataFrame):GetFrameLevel()
				local width = Math.Round(strataFrame:GetWidth())
				local height = Math.Round(strataFrame:GetHeight())
				local name = private.GetFrameName(strataFrame)
				if not strmatch(name, "innerBorderFrame") then
					print(format("  <%d%s> %s (%d, %d)", level, isTexture and "+" or "", name, width, height))

					-- Print element state if available
					local element = UIElements.GetByFrame(strataFrame)
					if element then
						for _, k in ipairs(ELEMENT_STYLE_KEYS) do
							local v = element[k]
							if v ~= nil then
								local vStr = private.GetStyleValueStr(v)
								if vStr then
									print(format("    %s = %s", tostring(k), vStr))
								end
							end
						end
					end
				end
			end
		end
	end
	print("=== End Dump ===")
end

function private.DumpFullFrame()
	print("=== TSM Full Frame Dump (all regions) ===")
	local x, y = GetCursorPosition()
	print(format("Cursor: %.2f, %.2f", x, y))

	-- Find the topmost frame under cursor
	local topFrame = nil
	local topLevel = -999
	local frame = EnumerateFrames()
	while frame do
		local isForbidden = false
		if frame.IsForbidden then
			local success, result = pcall(frame.IsForbidden, frame)
			isForbidden = success and result
		end
		if not isForbidden and frame:IsVisible() and MouseIsOver(frame) then
			local level = frame:GetFrameLevel()
			if level > topLevel then
				topLevel = level
				topFrame = frame
			end
		end
		frame = EnumerateFrames(frame)
	end

	if not topFrame then
		print("No frame found under cursor")
		return
	end

	local name = private.GetFrameName(topFrame)
	local width = Math.Round(topFrame:GetWidth())
	local height = Math.Round(topFrame:GetHeight())
	print(format("Top Frame: %s (%d, %d) level=%d", name, width, height, topLevel))

	-- Dump all regions
	local numRegions = topFrame:GetNumRegions()
	print(format("Total regions: %d", numRegions))
	for i = 1, numRegions do
		local region = select(i, topFrame:GetRegions())
		if region then
			local regionType = region:GetObjectType()
			local rWidth = Math.Round(region:GetWidth())
			local rHeight = Math.Round(region:GetHeight())
			local shown = region:IsShown()
			local visible = region:IsVisible()
			local mouseOver = MouseIsOver(region)

			if regionType == "FontString" then
				local text = region:GetText() or ""
				local r, g, b, a = region:GetTextColor()
				print(format("  [%d] FontString: w=%d h=%d shown=%s visible=%s mouseOver=%s text='%s' color=(%.2f,%.2f,%.2f,%.2f)",
					i, rWidth, rHeight, tostring(shown), tostring(visible), tostring(mouseOver), text, r, g, b, a))
			else
				print(format("  [%d] %s: w=%d h=%d shown=%s visible=%s mouseOver=%s",
					i, regionType, rWidth, rHeight, tostring(shown), tostring(visible), tostring(mouseOver)))
			end
		end
	end
	print("=== End Full Dump ===")
end

function private.DumpChildren()
	print("=== TSM Children Dump ===")
	local x, y = GetCursorPosition()
	print(format("Cursor: %.2f, %.2f", x, y))

	-- Find the topmost frame under cursor
	local topFrame = nil
	local topLevel = -999
	local frame = EnumerateFrames()
	while frame do
		local isForbidden = false
		if frame.IsForbidden then
			local success, result = pcall(frame.IsForbidden, frame)
			isForbidden = success and result
		end
		if not isForbidden and frame:IsVisible() and MouseIsOver(frame) then
			local level = frame:GetFrameLevel()
			if level > topLevel then
				topLevel = level
				topFrame = frame
			end
		end
		frame = EnumerateFrames(frame)
	end

	if not topFrame then
		print("No frame found under cursor")
		return
	end

	local name = private.GetFrameName(topFrame)
	print(format("Top Frame: %s level=%d", name, topLevel))

	-- Dump all children
	local numChildren = topFrame:GetNumChildren()
	print(format("Total children: %d", numChildren))
	for i = 1, numChildren do
		local child = select(i, topFrame:GetChildren())
		if child then
			local childName = private.GetFrameName(child)
			local cWidth = Math.Round(child:GetWidth())
			local cHeight = Math.Round(child:GetHeight())
			local shown = child:IsShown()
			local visible = child:IsVisible()
			local level = child:GetFrameLevel()
			print(format("  [%d] %s: w=%d h=%d level=%d shown=%s visible=%s", i, childName, cWidth, cHeight, level, tostring(shown), tostring(visible)))

			-- Dump regions of this child
			local numRegions = child:GetNumRegions()
			if numRegions > 0 then
				print(format("    Regions: %d", numRegions))
				for j = 1, numRegions do
					local region = select(j, child:GetRegions())
					if region then
						local regionType = region:GetObjectType()
						local rWidth = Math.Round(region:GetWidth())
						local rHeight = Math.Round(region:GetHeight())
						if regionType == "FontString" then
							local text = region:GetText() or ""
							local r, g, b, a = region:GetTextColor()
							print(format("      [%d] FontString: w=%d h=%d text='%s' color=(%.2f,%.2f,%.2f,%.2f)", j, rWidth, rHeight, text, r, g, b, a))
						else
							print(format("      [%d] %s: w=%d h=%d", j, regionType, rWidth, rHeight))
						end
					end
				end
			end
		end
	end
	print("=== End Children Dump ===")
end

function private.OnUpdate(self)
	if self.lastUpdate + 0.05 >= LibTSMDev.GetTime() then
		return
	end
	self.lastUpdate = LibTSMDev.GetTime()

	local numFrames = 0
	for _, strata in ipairs(STRATA_ORDER) do
		for _, strataFrame in ipairs(framesByStrata[strata]) do
			local name = private.GetFrameName(strataFrame)
			if not strmatch(name, "innerBorderFrame") then
				numFrames = numFrames + 1
			end
		end
	end
	if numFrames ~= private.tooltip.numFrames then
		private.tooltip.index = 1
		private.tooltip.numFrames = numFrames
	end

	local leftAltDown = IsAltKeyDown()
	local rightAltDown = false  -- 3.3.5 doesn't distinguish left/right alt
	if not self.altDown and leftAltDown and not rightAltDown then
		self.altDown = "LEFT"
		if private.tooltip.index == private.tooltip.numFrames then
			private.tooltip.index = 1
		else
			private.tooltip.index = private.tooltip.index + 1
		end
	elseif not self.altDown and not leftAltDown and rightAltDown then
		self.altDown = "RIGHT"
		if private.tooltip.index == 1 then
			private.tooltip.index = private.tooltip.numFrames
		else
			private.tooltip.index = private.tooltip.index - 1
		end
	elseif self.altDown == "LEFT" and not leftAltDown then
		self.altDown = nil
	elseif self.altDown == "RIGHT" and not rightAltDown then
		self.altDown = nil
	end

	for _, strata in ipairs(STRATA_ORDER) do
		wipe(framesByStrata[strata])
	end

	local frame = EnumerateFrames()
	while frame do
		-- IsForbidden() doesn't exist in 3.3.5, use pcall to check if frame is accessible
		local isForbidden = false
		if frame.IsForbidden then
			local success, result = pcall(frame.IsForbidden, frame)
			isForbidden = success and result
		end
		if frame ~= self.highlightFrame and not isForbidden and frame:IsVisible() and MouseIsOver(frame) and not IGNORED_FRAMES[frame:GetName() or ""] then
			local strata = frame:GetFrameStrata()
			if framesByStrata[strata] then
				tinsert(framesByStrata[strata], frame)
			end
			for _, region in Vararg.Iterator(frame:GetRegions()) do
				local regionForbidden = false
				if region.IsForbidden then
					local success, result = pcall(region.IsForbidden, region)
					regionForbidden = success and result
				end
				if region:IsObjectType("Texture") and not regionForbidden and region:IsVisible() and MouseIsOver(region) and UIElements.GetByFrame(region) then
					if framesByStrata[strata] then
						tinsert(framesByStrata[strata], region)
					end
				end
			end
		end
		frame = EnumerateFrames(frame)
	end

	self:ClearLines()
	self:AddDoubleLine("TSM Frame Stack", format("%0.2f, %0.2f", GetCursorPosition()))
	local currentIndex = 1
	local topFrame = nil
	for _, strata in ipairs(STRATA_ORDER) do
		if #framesByStrata[strata] > 0 then
			sort(framesByStrata[strata], private.FrameLevelSortFunction)
			self:AddLine(strata, 0.6, 0.6, 1)
			for _, strataFrame in ipairs(framesByStrata[strata]) do
				local isTexture = strataFrame:IsObjectType("Texture")
				local level = (isTexture and strataFrame:GetParent() or strataFrame):GetFrameLevel()
				local width = strataFrame:GetWidth()
				local height = strataFrame:GetHeight()
				local mouseEnabled = not isTexture and strataFrame:IsMouseEnabled()
				local name = private.GetFrameName(strataFrame)
				local isIndexedFrame = false
				if not strmatch(name, "innerBorderFrame") then
					if not topFrame and currentIndex == self.index then
						topFrame = strataFrame
						isIndexedFrame = true
					end
					currentIndex = currentIndex + 1
				end
				local text = format("  <%d%s> %s (%d, %d)", level, isTexture and "+" or "", name, Math.Round(width), Math.Round(height))
				if isIndexedFrame then
					self:AddLine(text, 0.9, 0.9, 0.5)
					local element = UIElements.GetByFrame(strataFrame)
					if element then
						for _, k in ipairs(ELEMENT_STYLE_KEYS) do
							local v = element[k]
							if v ~= nil then
								local vStr = private.GetStyleValueStr(v)
								if vStr then
									self:AddLine(format("    %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
								end
							end
						end
						local state = element._state:_GetData()
						if next(state) then
							self:AddLine("    _state = {", 0.7, 0.7, 0.7)
							for k, v in pairs(state) do
								local vStr = private.GetStyleValueStr(v)
								if vStr then
									self:AddLine(format("        %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
								end
							end
							self:AddLine("    }", 0.7, 0.7, 0.7)
						end
					elseif strataFrame.__debug and next(strataFrame.__debug) then
						self:AddLine("    __debug = {", 0.7, 0.7, 0.7)
						for k, v in pairs(strataFrame.__debug) do
							local vStr = private.GetStyleValueStr(v)
							if vStr then
								self:AddLine(format("        %s = %s", tostring(k), vStr), 0.7, 0.7, 0.7)
							end
						end
						self:AddLine("    }", 0.7, 0.7, 0.7)
					end
				elseif mouseEnabled then
					self:AddLine(text, 0.6, 1, 1)
				else
					self:AddLine(text, 0.9, 0.9, 0.9)
				end
			end
		end
	end
	self.highlightFrame:ClearAllPoints()
	self.highlightFrame:SetAllPoints(topFrame)
	self.highlightFrame:SetFrameStrata("TOOLTIP")
	self:Show()
end

function private.FrameLevelSortFunction(a, b)
	local aLevel = a:IsObjectType("Texture") and (a:GetParent():GetFrameLevel() + 0.1) or a:GetFrameLevel()
	local bLevel = b:IsObjectType("Texture") and (b:GetParent():GetFrameLevel() + 0.1) or b:GetFrameLevel()
	return aLevel > bLevel
end

function private.TableValueSearch(tbl, searchValue, currentKey, visited)
	visited = visited or {}
	for key, value in pairs(tbl) do
		if value == searchValue then
			return (currentKey and (currentKey..".") or "")..key
		elseif type(value) == "table" and (not value.__isa or UIElements.IsType(value, "Element")) and not visited[value] then
			visited[value] = true
			local result = private.TableValueSearch(value, searchValue, (currentKey and (currentKey..".") or "")..key, visited)
			if result then
				return result
			end
		end
	end
	for _, key in ipairs(ELEMENT_ATTR_KEYS) do
		local value = tbl[key]
		if value == searchValue then
			return (currentKey and (currentKey..".") or "")..key
		elseif type(value) == "table" and (not value.__isa or UIElements.IsType(value, "Element")) and not visited[value] then
			visited[value] = true
			local result = private.TableValueSearch(value, searchValue, (currentKey and (currentKey..".") or "")..key, visited)
			if result then
				return result
			end
		end
	end
end

function private.GetFrameNodeInfo(frame)
	local globalName = not frame:IsObjectType("Texture") and frame:GetName()
	if globalName and not strmatch(globalName, "^TSM_[A-Z_]+:") then
		return globalName, frame:GetParent()
	end

	local parent = frame:GetParent()
	local element = UIElements.GetByFrame(frame)
	if element then
		return element._id, parent
	end

	if parent then
		-- check if this exists as an attribute of the parent table
		local parentKey = Table.KeyByValue(parent, frame)
		if parentKey then
			return tostring(parentKey), parent
		end

		-- find the nearest element to which this frame belongs
		local parentElement = nil
		local testFrame = parent
		while testFrame and not parentElement do
			parentElement = UIElements.GetByFrame(testFrame)
			testFrame = testFrame:GetParent()
		end
		if parentElement then
			-- check if this exists as an attribute of this element
			local tableKey = private.TableValueSearch(parentElement, frame)
			if tableKey then
				return tableKey, parentElement._frame
			end
		end
	end

	return nil, parent
end

function private.GetFrameName(frame)
	local name, parent = private.GetFrameNodeInfo(frame)
	local parentName = parent and (private.GetFrameName(parent)..".") or ""
	name = name or gsub(tostring(frame), ": ?0*", ":")
	return parentName..name
end

function private.GetStyleValueStr(value)
	for key in pairs(COLOR_KEYS) do
		if value == Theme.GetColor(key) then
			return "ThemeColor<"..key..">"
		end
	end
	for key in pairs(FONT_KEYS) do
		if value == Theme.GetFont(key) then
			return "ThemeFont<"..key..">"
		end
	end
	if type(value) == "string" then
		return "\""..value.."\""
	elseif value ~= false then
		return tostring(value)
	end
	return nil
end
