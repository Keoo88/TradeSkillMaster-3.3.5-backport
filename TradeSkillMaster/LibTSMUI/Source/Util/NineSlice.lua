-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local NineSlice = LibTSMUI:DefineClassType("NineSlice")
local WidgetExtensions = LibTSMUI:Include("Util.WidgetExtensions")
local private = {
	styles = {},
}
local PART_ANCHORS = {
	topLeft = {
		{ "TOPLEFT" },
	},
	bottomLeft = {
		{ "BOTTOMLEFT" },
	},
	topRight = {
		{ "TOPRIGHT" },
	},
	bottomRight = {
		{ "BOTTOMRIGHT" },
	},
	left = {
		{ "TOPLEFT", "topLeft", "BOTTOMLEFT" },
		{ "BOTTOMLEFT", "bottomLeft", "TOPLEFT" },
	},
	right = {
		{ "TOPRIGHT", "topRight", "BOTTOMRIGHT" },
		{ "BOTTOMRIGHT", "bottomRight", "TOPRIGHT" },
	},
	top = {
		{ "TOPLEFT", "topLeft", "TOPRIGHT" },
		{ "TOPRIGHT", "topRight", "TOPLEFT" },
	},
	bottom = {
		{ "BOTTOMLEFT", "bottomLeft", "BOTTOMRIGHT" },
		{ "BOTTOMRIGHT", "bottomRight", "BOTTOMLEFT" },
	},
	center = {
		{ "TOPLEFT", "topLeft", "BOTTOMRIGHT" },
		{ "BOTTOMRIGHT", "bottomRight", "TOPLEFT" },
	},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Registers a nine-slice style.
---@param key string The style key
---@param info table The style info table
function NineSlice.__static.RegisterStyle(key, info)
	assert(not private.styles[key])
	private.styles[key] = info
	for part in pairs(PART_ANCHORS) do
		-- allowed to be missing the center part
		if part ~= "center" or info[part] ~= nil then
			assert(type(info[part].texture) == "string")
			assert(#info[part].coord == 4)
			assert(info[part].width > 0)
			assert(info[part].height > 0)
		end
	end
end

---Create an nine-slice object.
---@param frame table The parent frame
---@param subLayer? number The texture subLayer
---@param cancellables table The cancellables table to use
---@return NineSlice
function NineSlice.__static.New(frame, subLayer, cancellables)
	assert(frame and cancellables)
	return NineSlice(frame, subLayer, cancellables)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function NineSlice.__private:__init(frame, subLayer, cancellables)
	self._frame = frame
	self._parts = {} ---@type table<string,TextureExtended>
	self._styleKey = nil
	self._cancellables = cancellables

	-- Create all the textures
	for part in pairs(PART_ANCHORS) do
		self._parts[part] = self:_CreateTexture(subLayer or 0)
	end

	-- Set the points for all the textures
	for part, info in pairs(PART_ANCHORS) do
		for _, point in ipairs(info) do
			if #point == 1 then
				self._parts[part]:SetPoint(unpack(point))
			elseif #point == 3 then
				local anchor, relFrame, relAnchor = unpack(point)
				relFrame = self._parts[relFrame]
				assert(relFrame)
				self._parts[part]:SetPoint(anchor, relFrame, relAnchor)
			else
				error("Invalid point")
			end
		end
	end
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Hides the nine-slice
function NineSlice:Hide()
	for _, texture in pairs(self._parts) do
		texture:Hide()
	end
end

---Sets the style key.
---@param key string The style key
function NineSlice:SetStyle(key)
	local style = private.styles[key]
	for part, texture in pairs(self._parts) do
		local partStyle = style[part]
		if partStyle then
			texture:Show()
		else
			texture:Hide()
		end
	end
	if self._styleKey == key then
		return
	end
	self._styleKey = key
	for part, texture in pairs(self._parts) do
		local partStyle = style[part]
		if partStyle then
			texture:ClearAllPoints()
			for i, point in ipairs(PART_ANCHORS[part]) do
				local anchor, relFrame, relAnchor, xOff, yOff = nil, nil, nil, 0, 0
				if partStyle.offset then
					xOff, yOff = unpack(partStyle.offset[i])
				end
				if #point == 1 then
					anchor = unpack(point)
				elseif #point == 3 then
					anchor, relFrame, relAnchor = unpack(point)
					relFrame = self._parts[relFrame]
					assert(relFrame)
				else
					error("Invalid point")
				end
				if relFrame then
					texture:SetPoint(anchor, relFrame, relAnchor, xOff, yOff)
				else
					texture:SetPoint(anchor, xOff, yOff)
				end
			end
			texture:SetSize(partStyle.width, partStyle.height)
			texture:SetTexture(partStyle.texture)
			texture:SetTexCoord(unpack(partStyle.coord))
		end
	end
end

---Subscribes the vertex color.
---@param colorKey ThemeColorKey The color key
function NineSlice:SubscribeVertexColor(colorKey)
	for part in pairs(PART_ANCHORS) do
		self:SubscribePartVertexColor(part, colorKey)
	end
end

---Subscribes the vertex color of a single part.
---@param part string The nine slice part
---@param colorKey ThemeColorKey The color key
function NineSlice:SubscribePartVertexColor(part, colorKey)
	self._parts[part]:TSMSubscribeVertexColor(colorKey)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function NineSlice.__private:_CreateTexture(subLayer)
	local texture = WidgetExtensions.CreateTexture(self._frame, "BACKGROUND", subLayer or 0)
	texture:TSMSetCancellablesTable(self._cancellables)
	texture:SetBlendMode("BLEND")
	return texture
end
